#!/usr/bin/env bash

# based on https://github.com/eduardobaitello/kubelogs

set -e

VERSION="v1.0.0"

default_namespace="${KUBELOGS_NAMESPACE:-}"
default_output_dir="${KUBELOGS_OUTPUT_DIR:-}"
default_tail="${KUBELOGS_TAIL:--1}"
default_timestamps="${KUBELOGS_TIMESTAMPS:-false}"

NAMESPACE="${default_namespace}"
NAMESPACES=""
NAMESPACE_LIST=""
OUTPUT_DIR="${default_output_dir}"
TAIL="${default_tail}"
TIMESTAMPS="${default_timestamps}"
RESOURCES=""
RESOURCES_LIST=""

USAGE="kubelogs [-h] [-n] [-o] [-v] -- dump all kubernetes container logs to local files
kubelogs options:
    -h, --help           Show this help text
    -n, --namespace      Specify serveral namespaces with wildcard (e.g. 'kube-*')
    -o, --output-dir     Specify a output directory to skip the interactive selection
    -v, --version        Prints the kubelogs version

inherited from kubelogs:
    --tail               Lines of recent log file to dump (default: -1, all lines)
    --timestamps         Include timestamps on each line in the log output (default: false)
"

# get kubernetes resources yaml
function get_kubernetes_resources() {
  # split RESOURCES into array with comma as delimiter
  RESOURCES_LIST=(`echo ${RESOURCES} | tr ',' ' '`)
  for RESOURCE in "${RESOURCES_LIST[@]}"
  do
    echo "Getting ${NAMESPACE}/${RESOURCE} yaml info..."
    mkdir -p "$OUTPUT_DIR/${NAMESPACE}"
    kubectl get ${RESOURCE} --namespace=${NAMESPACE} -oyaml > "$OUTPUT_DIR/${NAMESPACE}/${RESOURCE}.yaml" || { echo "Error while getting ${RESOURCE} yaml!" >&2; }
  done
}

# Get namespace list from current context
function get_namespace_list() {
  NAMESPACE_LIST=(`kubectl get namespaces --output=jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | awk 'NF {print $1; print $1}'`)
  if [[ -z ${NAMESPACE_LIST[@]} ]]; then echo "No namespaces found for context $(kubectl config current-context)!" >&2; exit 1; fi
}

# Get pod list from selected namespace
function select_pods() {
  PODS=(`kubectl get pods --namespace=${NAMESPACE} --output=jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | awk 'NF {print $1; print $1}'`)
}

# Validate output directory
function validate_output_dir() {
  mkdir -p "$OUTPUT_DIR"
  if [[ -d $OUTPUT_DIR ]] && [[ -w $OUTPUT_DIR ]]; then
    return 0
  else
    return 1
  fi
}

# Select output directory
function select_output_dir() {
  OUTPUT_DIR=$(whiptail --inputbox "Enter a local directory for output file(s):" 8 78 --title "Directory" 3>&1 1>&2 2>&3)
  until validate_output_dir
  do
    whiptail --title "Output directory error" --yesno "Invalid directory or insuficient permissions! Try again?" 8 78
    OUTPUT_DIR=$(whiptail --inputbox "Enter a local directory for output file(s):" 8 78 --title "Directory" 3>&1 1>&2 2>&3)
  done
}
function get_all_pod_status() {
  mkdir -p "$OUTPUT_DIR"
  kubectl get pods -A -owide > "$OUTPUT_DIR/all_pods_status.log"
}
# get pod's status from NAMESPACE
function get_pod_status() {
  mkdir -p "$OUTPUT_DIR/${NAMESPACE}"
  kubectl get pods --namespace=${NAMESPACE} > "$OUTPUT_DIR/${NAMESPACE}/pod_status.log"
}

# get events from NAMESPACE
function get_events() {
  mkdir -p "$OUTPUT_DIR/${NAMESPACE}"
  kubectl get events --namespace=${NAMESPACE} > "$OUTPUT_DIR/${NAMESPACE}/events.log"
}

# Get container logs from NAMESPACE/PODS
function get_container_logs() {

    #TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
    # only get the logs from the running pods
    for pod in "${PODS[@]}"
    do
      PHASE=$(kubectl get pods --namespace=${NAMESPACE} ${pod} --output=jsonpath='{.status.phase}')
      CONTAINERSTATUS=$(kubectl get pods --namespace=${NAMESPACE} ${pod} --output=jsonpath='{.status.containerStatuses[*].ready}')
      echo "Getting ${pod} describe info..."
      mkdir -p "$OUTPUT_DIR/${NAMESPACE}/${pod}"
      kubectl describe pods --namespace=${NAMESPACE} ${pod} > "$OUTPUT_DIR/${NAMESPACE}/${pod}/describe_info_of_${pod}.log" || { echo "Error while getting ${pod} describe!" >&2; }
      echo "Getting ${pod} yaml info..."
      kubectl get pods --namespace=${NAMESPACE} ${pod} -oyaml > "$OUTPUT_DIR/${NAMESPACE}/${pod}/${pod}.yaml" || { echo "Error while getting ${pod} describe!" >&2; }
      if [[ "$PHASE" == "Running" ]];
        then
          CONTAINERS=(`kubectl get pods --namespace=${NAMESPACE} ${pod} --output=jsonpath='{.spec.containers[*].name}'`)
          for container in "${CONTAINERS[@]}"
          do
            set +e
            echo "Getting ${pod}/${container} logs..."
            mkdir -p "$OUTPUT_DIR/${NAMESPACE}/${pod}"
            kubectl logs --tail=${TAIL} --timestamps=${TIMESTAMPS} --namespace=${NAMESPACE} ${pod} --container=${container} > "$OUTPUT_DIR/${NAMESPACE}/${pod}/${container}.log" || { echo "Error while getting ${pod}/${container} logs!" >&2; }
            # add the previous logs if a pod is restarted
            RESTARTCOUNT=$(kubectl get pods --namespace=${NAMESPACE} ${pod} --output=jsonpath='{.status.containerStatuses[?(@.name == "'${container}'")].restartCount}')
            if [[ "$RESTARTCOUNT" != "0" ]];
              then
                echo "Getting ${pod}/${container} previous logs..."
                kubectl logs --tail=${TAIL} --timestamps=${TIMESTAMPS} --namespace=${NAMESPACE} ${pod} --container=${container} --previous > "$OUTPUT_DIR/${NAMESPACE}/${pod}/previous_log_of_${container}.log" || { echo "Error while getting ${pod}/${container} logs!" >&2; }
            fi
            set -e
          done
        fi
    done
}

# Parameters parsing
if [ "$#" -ne 0 ]; then
  while [ "$#" -gt 0 ]
  do
    case "$1" in
    # kubelog flags
    -h|--help)
          echo "$USAGE"
          exit 0
          ;;
    -v|--version)
          echo "$VERSION"
          exit 0
          ;;
    -n|--namespace)
          NAMESPACES="$2"
          ;;
    -r|--resources)
          RESOURCES="$2"
          ;;
    -o|--output-dir)
          if [ -z "$2" ]; then
            echo "ERROR: $1 cannot be empty" >&2
            exit 1
          else
            OUTPUT_DIR="$2"
            validate_output_dir || { echo "ERROR: Invalid output directory or insuficient permissions!" >&2; exit 1; }
          fi
          ;;
    # Flags inherited from kubelogs
    --tail)
          if [ -z "$2" ]; then
            echo "ERROR: $1 cannot be empty" >&2
            exit 1
          elif [[ ! "$2" =~ ^[0-9]+$ ]]; then
            echo "ERROR: Use an integer value for $1" >&2
            exit 1
          else
            TAIL="$2"
          fi
          ;;
    --timestamps)
          if [ -z "$2" ]; then
            echo "ERROR: $1 cannot be empty" >&2
            exit 1
          elif [ "$2" != "true" ] && [ "$2" != "false" ]; then
            echo "ERROR: Use \"true\" or \"false\" for $1" >&2
            exit 1
          else
            TIMESTAMPS="$2"
          fi
          ;;
    --)
          break
          ;;
    -*)
          echo "Invalid option '$1'. Use --help to see the valid options" >&2
          exit 1
          ;;
    # an option argument, continue
    *)  ;;
    esac
    shift
  done
fi

# Split NAMESPACES into array
IFS=',' read -ra INCLUDED_NAMESPACES <<< "$NAMESPACES"

# Call get_namespace_list function
get_namespace_list

# Call select_pod function for each namespace
for NAMESPACE in "${NAMESPACE_LIST[@]}"
do
  for INCLUDED_NAMESPACE in "${INCLUDED_NAMESPACES[@]}"
  do
    if [[ "$NAMESPACE" == ${INCLUDED_NAMESPACE} ]]; then
      select_pods

      # Call output_dir functions
      if [[ -z "$OUTPUT_DIR" ]]; then select_output_dir; fi

      # Call get_all_pod_status function
      get_all_pod_status
      # Call get_kubernetes_resources function
      get_kubernetes_resources
      # Call get_pod_status function
      get_pod_status
      # Call get_events function
      get_events
      # Call get_container_logs function
      get_container_logs
    fi
  done
done