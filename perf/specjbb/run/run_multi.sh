#!/usr/bin/env bash

echo "Backend opts: ${JAVA_OPTS_BE}"
echo "Number of runs: ${NUM_OF_RUNS}"
echo "Results dir: ${RESULTS_DIR}"

# Function to determine what is set in terms of NUMA, THP et als
function checkHostReadiness() {
  echo "=========================================================="
  echo "Running numactl --show to determine if/how numa is enabled"
  echo 
  numactl --show
  echo "=========================================================="

  echo "============================================================================================"
  echo "Running cat /sys/kernel/mm/transparent_hugepage/enabled to determine if we are using madvise"
  echo 
  cat /sys/kernel/mm/transparent_hugepage/enabled
  echo "============================================================================================"
}

# The main run script for SPECjbb2015 in MultiJVM mode
function runSpecJbbMulti() {

  for ((runNumber=1; runNumber<=NUM_OF_RUNS; runNumber=runNumber+1)); do

    # Create timestamp for use in logging, this is split over two lines as timestamp itself is a function
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)

    # Call sync to force any pending disk writes. Note the user typically needs to be in the sudoers file for this to work.
    echo "=============================================="
    echo "Starting sync to flush any pending disk writes"
    sync
    echo "sync completed                                "
    echo "=============================================="

    # The /proc/sys/vm/drop_caches file is a special interface in the Linux kernel for managing the system's cache.
    # 3: Clear both the page cache and the dentries/inodes cache (combined effect of 1 and 2).
    # Note, the user needs permission to write to this file (we use sudo tee for this)
    echo "==============================================="
    echo "Clearing the memory caches                     "
    echo 3 | sudo tee /proc/sys/vm/drop_caches
    echo "Memory caches cleared                          "
    echo "==============================================="

    # The /sys/kernel/mm/transparent_hugepage/enabled file is a special 
    # interface in the Linux kernel for managing how users can use THP.
    # madvise: Will allow the JVM to select what to use it for (heap only).
    # Note, the user needs permission to write to this file (we use sudo tee for this)
    echo "============================================================="
    echo "Setting madvise for THP                                      "
    echo madvise | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
    echo "madvise set                                                  "
    echo "============================================================="

    # Create temp result directory                
    local result
    result="${RESULTS_DIR%\"}"
    result="${result#\"}"
    mkdir -pv "${result}"
    
    # Copy current SPECjbb2015 config for this run to the result directory
    cp -r "${SPECJBB_CONFIG}" "${result}"
    cd "${result}" || exit
    
    # Start logging
    echo "==============================================="
    echo "Run $runNumber: $timestamp"
    echo "Launching SPECjbb2015 in MultiJVM mode...      "
    echo

    # JAVA is a previously exported environment variable coming in from testenv.mk and so we sanitize it
    JAVA="${JAVA%\"}"
    JAVA="${JAVA#\"}"

    echo "Starting the Controller JVM"
    # We don't double quote escape all arguments as some of those are being passed in as a list with spaces
    # shellcheck disable=SC2086
    local controllerCommand="${JAVA} ${JAVA_OPTS_C} ${SPECJBB_OPTS_C} -jar ${SPECJBB_JAR} -m MULTICONTROLLER ${MODE_ARGS_C} 2>controller.log 2>&1 | tee controller.out &"
    echo "$controllerCommand"
    eval "${controllerCommand}"

    # Save the PID of the Controller JVM
    CTRL_PID=$!
    echo "Controller PID = $CTRL_PID"

    # Sleep for 3 seconds for the controller to start. TODO This is brittle, let's detect proper controller start-up
    sleep 3

    local cpuCount=0

    # source the affinity script
    . "../../../perf/affinity.sh"
    
    local totalCpuCount=0
    # Extract total CPU count from affinity.sh
    totalCpuCount=$(get_cpu_count)

    if [ -z "$totalCpuCount" ]; then
      echo "ERROR: Could not determine total CPU count, exiting"
      exit 1
    fi

    echo "Detected $totalCpuCount CPUs"

    # Start the TransactionInjector and Backend JVMs for each group
    for ((groupNumber=1; groupNumber<GROUP_COUNT+1; groupNumber=groupNumber+1)); do

      local groupId="Group$groupNumber"

      echo -e "\nStarting Transaction Injector JVMs from $groupId:"

      # Calculate CPUs avaialble via NUMA for this run. We use some math to create a CPU range string
      # WARNING: We have hard coded this to work for a single run and a single group on a 64 core host
      # E.g if totalCpuCount is 64, then we should use 0-63
      local cpuInit=$((cpuCount*totalCpuCount))                 # 0 * 64 = 0
      local cpuMax=$(($(($((cpuCount+1))*totalCpuCount))-1))    # 1 * 64 - 1 = 63
      local cpuRange="${cpuInit}-${cpuMax}"                     # 0-63
      echo "cpuRange is $cpuRange"

      for ((injectorNumber=1; injectorNumber<TI_JVM_COUNT+1; injectorNumber=injectorNumber+1)); do

          local transactionInjectorJvmId="txiJVM$injectorNumber"
          local transactionInjectorName="$groupId.TxInjector.$transactionInjectorJvmId"

          echo "Start $transactionInjectorName"
          
          # We don't double quote escape all arguments as some of those are being passed in as a list with spaces
          # shellcheck disable=SC2086
          local transactionInjectorCommand="numactl --physcpubind=$cpuRange --localalloc ${JAVA} ${JAVA_OPTS_TI} ${SPECJBB_OPTS_TI} -jar ${SPECJBB_JAR} -m TXINJECTOR -G=$groupId -J=${transactionInjectorJvmId} ${MODE_ARGS_TI} > ${transactionInjectorName}.log 2>&1 &"
          echo "$transactionInjectorCommand"
          eval "${transactionInjectorCommand}"
          echo -e "\t${transactionInjectorName} PID = $!"

          # Sleep for 1 second to allow each transaction injector JVM to start. TODO this seems arbitrary
          sleep 1
      done

      local backendJvmId=beJVM
      local backendName="$groupId.Backend.${backendJvmId}"
      
      # Add GC logging to the backend's JVM options. We use the recommendended settings for Microsoft's internal GC analysis tool called Censum
      JAVA_OPTS_BE_WITH_GC_LOG="$JAVA_OPTS_BE -Xlog:gc*,gc+ref=debug,gc+phases=debug,gc+age=trace,safepoint:file=${backendName}_gc.log"

      echo " Start $BE_NAME"
      # We don't double quote escape all arguments as some of those are being passed in as a list with spaces
      # shellcheck disable=SC2086
      local backendCommand="numactl --physcpubind=$cpuRange --localalloc ${JAVA} ${JAVA_OPTS_BE_WITH_GC_LOG} ${SPECJBB_OPTS_BE} -jar ${SPECJBB_JAR} -m BACKEND -G=$groupId -J=$backendJvmId ${MODE_ARGS_BE} > ${backendName}.log 2>&1 &"
      echo "$backendCommand"
      eval "${backendCommand}"
      echo -e "\t$BE_NAME PID = $!"

      # Sleep for 1 second to allow each backend JVM to start. TODO this seems arbitrary
      sleep 1

      # Increment the CPU count so that we use a new range for the next run
      # TODO This is actually pointless as run and group = 1 in our current experiment
      cpucount=$((cpucount+1))
    done

    echo
    echo "SPECjbb2015 is running..."
    echo "Please monitor $result/controller.out for progress"

    wait $CTRL_PID
    echo
    echo "Controller has stopped"

    echo "SPECjbb2015 has finished"
    echo
    
    cd "${WORKING_DIR}" || exit

  done
}

checkHostReadiness
runSpecJbbMulti

# exit gracefully once we are done
exit 0
