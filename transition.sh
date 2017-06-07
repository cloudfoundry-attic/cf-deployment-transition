#!/bin/bash -e

# Colors!
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

SCRIPT_DIR=$(dirname $0)

function help() {
  echo -e "${GREEN}usage${NC}: $0 [required arguments]"
  echo "  required arguments:"
  echo -e "   ${GREEN}-ca, --ca-keys${NC}         Path to your created CA Keys file"
  echo -e "   ${GREEN}-cf, --cf-manifest${NC}     Path to your existing Cloud Foundry Manifest"
  echo -e "   ${GREEN}-d,  --diego-manifest${NC}  Path to your existiong Diego Manifest"
  echo -e "   ${GREEN}-h,  --help${NC}            Print this here message"
  echo "  optional arguments:"
  echo -e "   ${GREEN}-N,  --cf-networking${NC}   Flag to extract cf-networking creds from the Diego Manifest"
  echo -e "   ${GREEN}-r,  --routing${NC}      Flag to extract routing deployment creds from the Cloud Foundry Manifest"
}

function ca_key_stub_help() {
cat <<EOF
$(echo -e "${RED}You must create a Certificate Authority Key stub and provide it to $0.${NC}")
The file must be valid yaml with the following schema:
  ---
  from_user:
    diego_ca:
      private_key: |
        multi
        line
        example
        key
    etcd_ca:
      private_key: |
    etcd_peer_ca:
      private_key: |
    consul_agent_ca:
      private_key: |
    loggregator_ca:
      private_key: |
    uaa_ca:
      private_key: |

$(echo -e "${GREEN}More details can be found in our README.md${NC}")
EOF
  echo
}

function check_params() {
  local ca_keys=false
  local cf_manifest=false
  local diego_manifest=false
  local error_message="${RED}Error: ${NC}"

  if [[ -f $CA_KEYS ]]; then
    ca_keys=true
  else
    echo $CA_KEYS
    error_message="$error_message CA keys stub required."
  fi

  if [[ -f $CF_MANIFEST ]]; then
    cf_manifest=true
  else
    error_message="$error_message CF manifest required."
  fi

  if [[ -f $DIEGO_MANIFEST ]]; then
    diego_manifest=true
  else
    error_message="$error_message Diego manifest required."
  fi

  if [[ $ca_keys == false || $cf_manifest == false || $diego_manifest == false ]]; then
    echo -e $error_message
    echo
    help
    echo
    if [[ $ca_keys == false ]]; then
      ca_key_stub_help
    fi
    exit 1
  fi
}

function parse_args() {
  while [[ $# -gt 0 ]]
  do
    key="$1"
    case $key in
      -ca|--ca-keys)
      CA_KEYS="$2"
      shift # past argument
      ;;
      -cf|--cf-manifest)
      CF_MANIFEST="$2"
      shift # past argument
      ;;
      -d|--diego-manifest)
      DIEGO_MANIFEST="$2"
      shift # past argument
      ;;
      -N|--cf-networking)
      CF_NETWORKING=true
      ;;
      -r|--routing)
      ROUTING=true
      ;;
      -h|--help)
      help
      exit 0
      ;;
      *)
              # unknown option
      ;;
    esac
    shift # past argument or value
  done
}

function prettify_spiff_errors() {
  local spiff_temp_output
  spiff_temp_output=${1}
  # There must be error output.  Use it to find which key(s) we're missing.
  local all_the_cas="diego_ca etcd_ca etcd_peer_ca uaa_ca consul_agent_ca loggregator_ca"
  for ca in $all_the_cas
  do
    check_ca_private_key $ca $spiff_temp_output
  done
}

function check_ca_private_key() {
  local ca_key_name=$1
  local ca_key_error=""
  local spiff_temp_output
  spiff_temp_output=${2}

  ca_key_error=$(cat $spiff_temp_output | grep merge | grep $ca_key_name) || true
  if [[ $ca_key_error != "" ]]; then
    echo "CA Key [ $ca_key_name ] not found in [ $CA_KEYS ]!"
  fi
}

function extract_uaa_jwt_value() {
  local uaa_jwt_spiff_template
  uaa_jwt_spiff_template="${1}"

  uaa_jwt_active_key=$(bosh interpolate $CF_MANIFEST --path=/properties/uaa/jwt/policy/active_key_id)
  uaa_jwt_value=$(bosh interpolate $CF_MANIFEST --path=/properties/uaa/jwt/policy/keys/${uaa_jwt_active_key}/signingKey | sed -e 's/^/    /')

  cat > $uaa_jwt_spiff_template << EOF
uaa_jwt_signing_key:
  private_key: |+
${uaa_jwt_value}
EOF
}

function spiff_it() {
  uaa_jwt_spiff_template=$(mktemp)

  extract_uaa_jwt_value "${uaa_jwt_spiff_template}"

  if [ -n "${CF_NETWORKING}" ] && [ -n "${ROUTING}" ]; then
    MERGE_TEMPLATES="$SCRIPT_DIR/templates/vars-store-cf-networking-and-routing-template.yml $SCRIPT_DIR/templates/vars-pre-processing-cf-networking-and-routing-template.yml"
  elif [ -n "${CF_NETWORKING}" ]; then
    MERGE_TEMPLATES="$SCRIPT_DIR/templates/vars-store-cf-networking-template.yml $SCRIPT_DIR/templates/vars-pre-processing-cf-networking-template.yml"
  elif [ -n "${ROUTING}" ]; then
    MERGE_TEMPLATES="$SCRIPT_DIR/templates/vars-store-routing-template.yml $SCRIPT_DIR/templates/vars-pre-processing-routing-template.yml"
  else
    MERGE_TEMPLATES="$SCRIPT_DIR/templates/vars-store-template.yml $SCRIPT_DIR/templates/vars-pre-processing-template.yml"
  fi

  spiff merge \
  $MERGE_TEMPLATES \
  $SCRIPT_DIR/templates/vars-ca-template.yml \
  $CF_MANIFEST \
  $DIEGO_MANIFEST \
  $CA_KEYS \
  $uaa_jwt_spiff_template
}

function handle_spiff_errors() {
  set +e
  spiff_temp_output=$(mktemp)
  # spiff_it > /dev/null
  spiff_it 1> /dev/null 2> $spiff_temp_output
  set -e
  echo $spiff_temp_output
  cat $spiff_temp_output
  if [ $(cat $spiff_temp_output | wc -l) == 0 ]; then
    spiff_it > deployment-vars.yml
    echo -e "${GREEN}Merge successful!${NC}"
    echo "Please find your new vars store file in $PWD/deployment-vars.yml"
  else
    prettify_spiff_errors $spiff_temp_output
    cat $spiff_temp_output > /dev/stderr
    exit 1
  fi
}

function main() {
  check_params
  handle_spiff_errors
}

parse_args "$@"
main
