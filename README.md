UNDER DEVELOPMENT -- Post your questions on Google Groups https://groups.google.com/forum/#!forum/big-bench
 for help any help in running the workload.
 
 To collect performance metrics from  Hadoop nodes and analyze the resource utilization draw automated charts using MS-Excel, PAT is available for download.
 
 https://github.com/intel-hadoop/PAT 

======

This document is a development version and describes the BigBench installation and execution on our AWS machines.

# Preparation

## Cluster Environment

**Java**

Java 1.7 is required. 64 bit is recommended

**Hadoop**

* Hive 0.12 recommended
* Mahout

## Installation

On the AWS installation, clone the github repository into a folder stored in $INSTALL_DIR:

```
export INSTALL_DIR="$HOME" # adapt this to your location
cd $INSTALL_DIR
git clone https://<username>@github.com/intel-hadoop/Big-Bench.git
```

## Configuration

Check if the hadoop related variables are correctly set in the environment file:

`vi "$INSTALL_DIR/Big-Bench/setEnvVars"`

Major settings, Specify your cluster environment:

```
BIG_BENCH_HADOOP_LIBS_NATIVE  (optional but speeds up hdfs access)
BIG_BENCH_HADOOP_CONF         most important: core-site.xml and hdfs-site.xml
```
Minor settings:
```
BIG_BENCH_USER
BIG_BENCH_DATAGEN_DFS_REPLICATION  replication count used during generation of the big bench table
BIG_BENCH_DATAGEN_JVM_ENV          -Xmx750m is sufficient for Nodes with 2 CPU cores, remove or increase if your Nodes have more cores
```
# Run the workload

There are two different methods for running the workload: use the driver to simply perform a complete benchmark run or use the bash scripts to do partial tests. As the driver calls the bash scripts internally, both methods yield the same results.

## Common hints

The following paragraphs are important for both methods.

### Accept license

When running the data generator for the first time, the user must accept its license:

```
By using this software you must first agree to our terms of use. Press [ENTER] to show them
... # license is displayed
If you have read and agree to these terms of use, please type (uppercase!): YES and press [ENTER]
YES
```

### PDGF
The data are being generated directly into HDFS (into the $BIG_BENCH_HDFS_RELATIVE_INIT_DATA_DIR directory, absolute HDFS path is $BIG_BENCH_HDFS_ABSOLUTE_INIT_DATA_DIR).

Default HDFS replication count is 1 (data is only stored on the generating node). You can change this in the $BIG_BENCH_HOME/setEnvVars file by changing the variable
`BIG_BENCH_DATAGEN_DFS_REPLICATION=<Replication count>'.

## Using the BigBench driver

The BigBench driver is started with a script. To show all available options, you can call the help first:
```
"$INSTALL_DIR/scripts/bigBench runBenchmark -h
```

### Quick start

If a complete benchmark run should be performed and no data were generated previously, this is the command which should be executed:

```
"$INSTALL_DIR/scripts/bigBench runBenchmark -m <number of map tasks for data generation> -f <scale factor of dataset> -s <number of parallel streams in the throughput test>
```

This command will generate data, run the load-, power- and throughput-test and calculate the BigBench result.

So a complete benchmark run with all stages can be done by running (e.g., 4 map tasks, scale factor 100, 2 streams):
```
"$INSTALL_DIR/scripts/bigBench runBenchmark -m 4 -f 100 -s 2
```

After the benchmark finished, two log files are written: BigBenchResult.txt (which contains the driver's sysout messages) as well as BigBenchTimes.csv (which contains all measured timestamps/durations). The log directory can be specified with the -l option, it defaults to the BigBench's log dir ($BIG_BENCH_LOGS_DIR).

### More detailed explanation

There are four phases the driver traverses (only three are benchmarked though): data generation, load test, power test and throughput test. The driver has a clean option (-c) which does not run the benchmark but rather cleans the environment from previous runs (if for some reason all generated data should be cleaned).

#### Data generation

The data generation phase is not benchmarked by BigBench. The driver can skip this phase by setting "-sd". Skipping this phase is a good idea if data were already generated previously and the complete benchmark should be repeated with the same dataset size. In that case, generting data is not necessary as PDGF would generate the exact same data as in the previous run. If data generation is not skipped, two other options must be provided to the driver: "-m" sets the number of map tasks for PDGF's data generation, "-f" sets the scale factor determining the dataset size (1 scale factor equals 1 GiB). If "-c" is set and "-sd" is not set, the dataset directory in HDFS will be deleted.

#### Load test

Population of the hive metastore is the first phase that is benchmarked by BigBench. This phase can be skipped by providing "-sl" as an option. Re-populating the metastore is technically only necessary if the dataset has changed. Nevertheless, metastore population is part of the benchmark, so if this phase is skipped then no BigBench result can be computed. If "-c" is set and "-sl" is not set, the tables of the dataset in the metastore will be dropped (however it does not influence the query results from later tests).


#### Power test

This is the second phase that is benchmarked by BigBench. All queries run sequentially in one stream. The phase can be skipped with the option "-sp". Setting "-c" (and not "-sp") cleans previous power-test's results in the hive metastore tables and HDFS directories.

#### Throughput test

The throughput test is the last benchmark phase. All queries run in parallel streams in different order. The phase can be skipped with "-st". If this phase is not skipped, "-s" is a required option because that sets the number of parallel streams used in this phase. As in the other phases, setting "-c" (and not "-st") cleans the thoughput-test's results in the hive metastore and the HDFS directories.

## Using the bigBench bash script

The driver internally calls the $BIG_BENCH_BASH_SCRIPT_DIR/bigBench bash script along with a module name. So every step the driver performs (apart from the more complicated "query mixing" and multi-stream execution logic) can be run manually by executing this script with the proper options.

### Overview

The general syntax for the bigBench script is:
```
"$INSTALL_DIR/scripts/bigBench [global options] moduleName [module options]
```

At the moment there is only one module which processes module options itself, namely runBenchmark. All other modules currently do NO option processing. They rely on bigBench for option processing. Therefore when not running the runBenchmark module, global options must be specified.

All available options as well as all found modules can be listed by calling the script help:
```
"$INSTALL_DIR/scripts/bigBench -h
```

### Available options
* -b: This option chooses which binary will be used for the benchmark. WARNING: support for choosing other binaries than "hive" is implemented, but hive is the only tested binary. In fact, no other binary works so far. DO NOT USE THAT OPTION
* -d: Some more complex queries are split into multiple internal parts. This option chooses which internal query part will be executed. This is a developer only option. ONLY USE IF YOU KNOW WHAT YOU ARE DOING
* -f: The scale factor for PDGF. It is used by the clusterDataGen and hadoopDataGen modules
* -h: Show help
* -m: The map tasks used for data generation. It is used by the clusterDataGen and hadoopDataGen modules
* -p: The benchmark phase to use. It is necessary if subsequent query runs should not overwrite results of previous queries. The driver internally uses POWER_TEST_IN_PROGRESS, THROUGHPUT_TEST_FIRST_QUERY_RUN_IN_PROGRESS and THROUGHPUT_TEST_SECOND_QUERY_RUN_IN_PROGRESS. The default value when not providing this option is RUN_QUERY
* -q: Defines the query number to be executed
* -s: This option defines the number of parallel streams to use. It is only of any use with the runQueryInParallel module
* -t: Sets the stream number of the current query. This option is important so that one query can run multiple times in parallel without interfering with other instances
* -v: Use the provided file as initial metastore population script
* -w: Use the provided file as metastore refresh script
* -y: Use the provided file for custom query parameters
* -z: Use the provided file for custom hive settings

### Modules usage examples

* cleanData: cleans the dataset directory in HDFS. This module is automatically run by the data generator module to remove the dataset from the HDFS.
```
"$INSTALL_DIR/scripts/bigBench cleanData
```

* cleanMetastore: cleans the metastore dataset tables.
```
"$INSTALL_DIR/scripts/bigBench [-z <hive settings>] cleanMetastore
```

* cleanQueries: cleans all metastore tables and result directories in HDFS for all 30 queries. This module works as a wrapper for cleanQuery and does not work if "-q" is set as option.
```
"$INSTALL_DIR/scripts/bigBench [-p <benchmark phase>] [-t <stream number] [-z <hive settings>] cleanQueries
```

* cleanQuery: cleans metastore tables and result directories in HDFS for one query. Needs the query number to be set.
```
"$INSTALL_DIR/scripts/bigBench [-p <benchmark phase>] -q <query number> [-t <stream number] [-z <hive settings>] cleanQuery
```

* clusterDataGen: generates data using ssh on all defined nodes. This module is deprecated. Do not use it.

* hadoopDataGen: generates data using a hadoop job. Needs the map tasks and scale factor options.
```
"$INSTALL_DIR/scripts/bigBench -m <map tasks> -f <scale factor> hadoopDataGen
```

* populateMetastore: populates the metastore with the dataset tables.
```
"$INSTALL_DIR/scripts/bigBench [-v <population script>] [-z <hive settings>] populateMetastore
```

* refreshMetastore: refreshes the metastore with the refresh dataset.
```
"$INSTALL_DIR/scripts/bigBench [-w <refresh script>] [-z <hive settings>] refreshMetastore
```

* runBenchmark: runs the driver. This module parses its options itself. For details look at the driver usage section above.
```
"$INSTALL_DIR/scripts/bigBench runBenchmark [driver options]
```

* runQueries: runs all 30 queries sequentially. This module works as a wrapper for runQuery and does not work if "-q" is set as option.
```
"$INSTALL_DIR/scripts/bigBench [-p <benchmark phase>] [-t <stream number] [-z <hive settings>] runQueries
```

* runQuery: runs one query. Needs the query number to be set.
```
"$INSTALL_DIR/scripts/bigBench [-p <benchmark phase>] -q <query number> [-t <stream number] [-z <hive settings>] runQuery
```

* runQueryInParallel: runs one query on multiple parallel streams. This module is a wrapper for runQuery. Needs the query number ("-q") and total number of streams ("-s") to be set and the stream number ("-t") to be unset.
```
"$INSTALL_DIR/scripts/bigBench [-p <benchmark phase>] -q <query number> -s <number of parallel streams> [-z <hive settings>] runQueryInParallel
```

* showErrors: parses query errors in the log files after query runs.
```
"$INSTALL_DIR/scripts/bigBench showErrors
```

* showTimes: parses execution times in the log files after query runs.
```
"$INSTALL_DIR/scripts/bigBench showTimes
```

* zipQueryLogs: generates a zip file of all logs in the logs directory. It is run by the driver after each complete benchmark run. Subsequent runs override the old log files. A zip archive is created to save them before being overwritten.
```
"$INSTALL_DIR/scripts/bigBench zipQueryLogs
```

# FAQ 
This Benchmark does not favour any platform and we ran this benchmark on many different distributions. But you gotta start somewhere.
This Benchmark is also not HIVE specify, but hive happens to be the first module to be implemented.

This FAQ is mostly based on our experiments with Hive on Yarn with CDH 5.x)


## Where do i put my cluster specific settings?
=============================================
Here: Big-Bench/setEnvVars

Where is my core-site.xml/hdfs-site.xml  for BIG_BENCH_HADOOP_CONF (usually the one in /etc/hadoop/...):

`find / -name "hdfs-site.xml" 2> /dev/null`

Where is my hdfs native libs folder for BIG_BENCH_HADOOP_LIBS_NATIVE?

`find / -name "libhadoop.so" 2> /dev/null`


What is my name node address for BIG_BENCH_HDFS_NAMENODE? 

Look inside your hdfs-site.xml and locate this property value:
``` 
<property>
    <name>dfs.namenode.servicerpc-address</name>
    <value>host.domain:8022</value>
</property>
```

## Where do i put benchmark specific hive options?
Big-Bench/hive/hiveSettings.sql

There are already a number of documented settings in there.


## Where do i put query specific hive options?
You can place an optional file "hiveLocalSettings.sql" into a queries folder e.g.:

Big-Bench/queries/q??/hiveLocalSettings.sql

You can put your query specific settings into this file, and the benchmark will automatically load the file. Its made so, that the hiveLocalSettings.sql file gets loaded last, which allows you to override any previously made settings made in e.g.: Big-Bench/hive/hiveSettings.sql
This way your settings are independent from github updates and there wont be any conflicts when updating the query files. 


## Underutilized cluster 

### cluster setup
Before "tuning" or asking in the google group, please ensure that your cluster is well configured and able to utilize all resources (cpu/mem/storage/netIO).


There are a lot of things you have to configure, depending on your hadoop distribution and your hardware.
Some important variables regarding MapReduce task performance:
```
mapreduce.reduce.memory.mb
mapreduce.map.memory.mb
mapreduce.map.memory.mb
mapreduce.map.memory.mb
mapreduce.reduce.java.opts;
mapreduce.map.java.opts
mapreduce.map.java.opts
mapreduce.task.io.sort.mb
mapreduce.task.io.sort.mb
...
```

Basically, you may want to have at least as much (yarn) "containers" (container may hold a map or a reduce task) on your cluster as you have CPU cores or hardware threads.
Despite that, you configure your container count based on available memory in your cluster. 1-2GB of memory per container may be a good starting point.

In CDH you can do this with: (just example values! follow a more sophisticated tutorial on how to set up your cluster!):

**Gateway**
Gateway BaseGroup --expand--> Resource management
```
Container_Size (e.g.:  1,5Gb can be sufficient but you may require more if you run into "OutOfMemory" or "GC overhead exceeded" errors while executing this benchmark) 
mapreduce.map.memory.mb=Container_Size
mapreduce.reduce.memory.mb=Container_Size
mapreduce.map.java.opts.max.heap =0.75*Container_Size
mapreduce.reduce.java.opts.max.heap =0.75*Container_Size
Client Java Heap Size in Bytes =0.75*Container_Size
```

**Nodemanager**
Nodemanager BaseGroup --expand--> Resource management
```
 -container memory
 how many memory ,all containers together, can allocate (physical "free" resources on nodes)
 - yarn.nodemanager.resource.cpu-vcores (same rules as container memory)
```

**ResourceManager**
ResourceManager BaseGroup --expand--> Resource management
```
 -yarn.scheduler.minimum-allocation-mb  (set to 512mb or 1GB)
 -yarn.scheduler.maximum-allocation-mb  (hint: container memory/container max mem == minimum amount of containers per node)
 -yarn.scheduler.increment-allocation-mb  set to 512MB
 -yarn.scheduler.maximum-allocation-vcores  set to min amount of containers
```

**Dynamic resource pools**
(cluster -> dynamic resource pools -> configuration)
```
If everything runs fine, do not set anything here (no additional restrictions). 
If you experience yarn deadlocks (yarn trying to allocate resources, but fails leading to MR-jobs waiting indefinitely for containers)  you may want set a limit.
```


### datagen stage: Tuning the DataGeneration tool

**right settings for number of map tasks (bigBench -m option)**

Short answer:
On map task per virtual CPU/hardware thread is best to utilize all CPU resources.

But settings in your cluster may not allow you executing this number of map tasks in parallel. Basically you can not run more parallel map tasks then available (yarn-) containers.
Another thing to consider when testing on big noisy clusters, is the non homogeneous runtime of nodes or node failures. Most mappers may finish long before certain others. To address for this skew in mapper runtime we suggest to set the number of mappers to a multiple (2-3 times) of available containers/threads in your cluster, reducing the runtime of a single mapper and making it cheaper to restart a task.
But be aware that a to short runtime per map tasks also hurts performance, because launching a task is associated with a considerable amount of overhead. In addition to that, more map tasks produce more intermediate files and thus causing more load for the HDFS namenode.
Try targeting run times per mapper not shorter than 3 minutes.

For a "small cluster" (4nodes á 40 hardware threads) (4Nodes * 40Threads) * 2 = 320 MapTasks may be a good value.


**advanced settings**

If your cluster has more available threads then concurrently runnable containers, your cluster may be CPU underutilized.
In this case you can increase the number of threads available to the data generation tool. The data generation tool will then allocate the specified number of threads per map task.

Please open you Big-Bench/setEnvVars configuration file and see lines:
  export BIG_BENCH_DATAGEN_JVM_ENV=" -Xmx300m "        
and:   
  export BIGBENCH_DATAGEN_HADOOP_OPTIONS=" -workers 1 -ap 3000 "   

You could set
  export BIGBENCH_DATAGEN_HADOOP_OPTIONS=" -workers 4 -ap 3000 "
telling the data generation tool to use 4 threads per map task.
Note: increasing the number of threads  requires lager internal buffers so please add 100Mb of memory to  BIG_BENCH_DATAGEN_JVM_ENV per additional thread.

Your final settings for 4 threads per map task should look like this:
  export BIG_BENCH_DATAGEN_JVM_ENV=" -Xmx600m "
  export BIGBENCH_DATAGEN_HADOOP_OPTIONS=" -workers 4 -ap 3000 " 
  

One map task per virtual CPU/hardware thread is best to utilize all CPU resources.

But settings in your cluster may not allow you executing this number of map tasks in parallel. Basically you can not run more parallel map tasks then available (yarn-) containers.
Another thing to consider when testing on big noisy cluster, is the non homogeneous runtime of nodes or node failures. Most mappers may finish long before certain others. To address for this skew in mapper runtime i would suggest to set the number of mappers to a multiple (2-3 times) of available containers/threads in your cluster, reducing the runtime of a single mapper and making it cheaper to restart a task.
But be aware that a to short runtime per map tasks also hurts performance. I would suggest targeting run times per mapper not shorter > 5min.




### Hive "loading"-stage is slow,
The hive loading stage is not only "moving" file in hdfs from the data/ dir into the hive/warehouse.

Big-Bench hive does not work on the plain CSV files, but instead transforms the files into the ORC file format, more efficient and native to hive.
Big-Bench models a set of long running analytic queries. Thus it is more realistic not to store the tables in plain text format but in a optimized fashion.

Transforming data into ORC is a very expensive tasks (index creation, compression, splitting and distributing/replication across the cluster) and loading the tables into hive is done by a single hive job. Since there are 23 distinct tables, hive will always create at least 23 hadoop jobs to do the CSV->ORC processing.

You could test if activating the following options on your cluster work for you:
hive.exec.parallel=true
hive.exec.parallel.thread.number=8

They allow hive to run multiple uncorrelated jobs in parallel (like creating tables). But be warned, this feature is still considered unstable (Hive 0.12).
If you cant modify your hive-site.xml cluster globally, you can uncomment/add these options in:
  BigBench/hive/hiveCreateLoadORC.sql  
to active them only for the loading stage or in:
  Big-Bench/hive/hiveSettings.sql
to enable them for the whole benchmark, including the queries.

### Hive Query's are running slow
Unfortunately there is no generic answer to this. 
First: this is a long running benchmark with hundreds of distinct mr-Jobs. Each mr-Job has a significant amount of "scheduling" overhead of around ~1minute. So even if you are only processing no data at all, you still have to pay the price of scheduling everything (which is arround 1,5 hours! for a single wave of all 30 queries).
There are several projects trying to reduces this problem like TEZ from the stinger imitative or Hive on Spark or SparkSQL. But with Hive on yarn, there is nothing you can really do about this.

**Enough data (/bigBench -f <SF> option) ?**

Make sure you run your benchmark with a big enough dataset to reduce the ratio of fixed overhead time vs. total runtime. Besides from initial testing your cluster setup, never run with a scaling factor of smaller than 100 ( -f 100 ==100GB)


**Enough map/reduce tasks per query stage ?**


Look in your logs and search for lines like this:
```
Hadoop job information for Stage-2: number of mappers: 1; number of reducers: 1
```

If the number of mappers/reducers is < than your available (yarn) slots or "tasks" you cluster is able to run (Rough estimate:  slots == number of CPU# in your cluster or: TotalClusterRAM/slotMaxMem), the query is not using all your clusters resources.
But don't generalize this. Some stages simply don't have enough data to justify more than 1 map job (e.g. the final stage of a "... limit 100 SORT BY X;" query only has to sort 100 lines).
Or the processed table is just to small (like the time or date table).
Remember that more map/reduce tasks also implies more overhead. So don't overdo it as to much map tasks can hurt performance just like to few tasks.

You can tune some parameters in the hive/hiveSettings.sql file. 
Hive determines the number of map/reduce tasks based on the tables size. If you have a table of 670MB and set the max.split.size to 67000000 bytes, hive will start 10 map tasks to process this table (or maybe less if hive is able to reduce the dataset by using partitioning/bucketing)

```
set mapred.max.split.size=67108864;
set mapred.min.split.size=1;
set hive.exec.reducers.max=99999;
```


## More detailed log files

The aggregated yarn application log file created for a yarn job contains much more information than the default printout you see on your screen.
This log file is especially helpful to debug child-processes started by hadoop MR-jobs. e.g. java/pyhton scripts in certain streaming api using queries), or  the "hadoopDataGeneration" task which executes the data generator program.

To retrieve this log please follow these steps:

In your Big-Bench/logs/ folder files or on screen you will find a line similar to this:

14/06/17 19:40:12 INFO impl.YarnClientImpl: Submitted application application_1403017220075_0022

To extract this line from the log file(s) execute:
```
grep "Submitted application" ${BIG_BENCH_LOGS_DIR}/<log file of interest>.log
```

The important part is the application ID (e.g. application_1403017220075_0022) itself.
Take this ID and request the associate yarn log file using the following command line:
```
yarn logs -applicationId <applicationID>  > yarnApplicationLog.log
```


## Exceptions/Errors you may encounter


### Execution of a MR Stage progresses quickly but then seems to "hang" at ~99%.

This indicates a skew in the data. This means: most reducers handle only very little data, and some (1-2) have to handle most of the data.  This happens if some keys are very frequent in comparison to others. 
e.g.: this is the case for user_sk in web_clickstreams. 50% of all clicks have user_sk == NULL (indicating that the click-stream did not result in a purchase).
When a query uses the "distribute by " keyword, hive distributes the workload by this key. This implies that every reducer handles a specific set of keys. The single reducer responsible for the "null" key then effectively has to process >50% of the total workload (as 50% of all keys are null).

We did our best to filter out null keys within the querys, if the null values are irrelevant for the query result.  This does not imply that all hive querys are "skew-free". Hive offers some settings to tune this:
```
set hive.optimize.skewjoin=true;
set hive.optimize.skewjoin.compiletime=true;
set hive.groupby.skewindata=true;
set hive.skewjoin.key=100000;
-- read: https://issues.apache.org/jira/browse/HIVE-5888
```
But be aware that turning on these options will produce worse! running times for data/queries that are not heavily skewed, which is the reason they are disabled by default. 


### Execution failed with exit status: 3
```
Execution failed with exit status: 3
FAILED: Execution Error, return code 3 from org.apache.hadoop.hive.ql.exec.mr.MapredLocalTask
```

Hive converted a join into a locally running and faster 'mapjoin', but ran out of memory while doing so.
There are two bugs responsible for this.


**Bug 1)**

hives metric for converting joins miscalculated the required amount of memory. This is especially true for compressed files and ORC files, as hive uses the filesize as metric, but compressed tables require more memory in their uncompressed 'in memory representation'.

You could simply decrease 'hive.smalltable.filesize' to tune the metric, or increase 'hive.mapred.local.mem' to allow the allocation of more memory for map tasks.

The later option may lead to bug number two if you happen to have a affected hadoop version.

**Bug 2)**

Hive/Hadoop ignores  'hive.mapred.local.mem' !
(more exactly: bug in Hadoop 2.2 where hadoop-env.cmd sets the -xmx parameter multiple times, effectively overriding the user set hive.mapred.locla.mem setting. 
see: https://issues.apache.org/jira/browse/HADOOP-10245

**There are 3 workarounds for this bug:**

* 1) assign more memory to the local! Hadoop JVM client (this is not! mapred.map.memory) because map-join child jvm will inherit the parents jvm settings
 * In cloudera manager home, click on "hive" service,
 * then on the hive service page click on "configuration"
 * Gateway base group --(expand)--> Resource Management -> Client Java Heap Size in Bytes -> 1GB 
* 2) reduce "hive.smalltable.filesize" to ~1MB or below (depends on your cluster settings for the local JVM)
* 3) turn off "hive.auto.convert.join" to prevent hive from converting the joins to a mapjoin.

2) & 3) can be set in Big-Bench/hive/hiveSettings.sql


### Cannot allocate memory

```
Cannot allocate memory
There is insufficient memory for the Java Runtime Environment to continue.
```

Native memory allocation (malloc) failed to allocate x bytes for committing reserved memory. 

Basically your kernel handed out more memory than actually available, in expectants that most programs actually never use (allocate) every last bit of memory they request. Now a program (in this case java) tries to allocate something in its virtual reserved memory area, but the kernel was wrong with his estimation of application memory consumption and there is no physical memory left available to fulfil the applications malloc request.
http://www.oracle.com/technetwork/articles/servers-storage-dev/oom-killer-1911807.html

**WARNING:**
Some "fixes" suggest disabling  "vm.overcommit_memory" in the kernel.
If you are already in an "overcommitted" state DO NOT SET sysctl vm.overcommit_memory=2 on the running machine to "cure" it! If you do, you will no longer be able to execute ANY program or shell command, as this would require a memory allocation of which nothing is left. This essentially will deadlock you machine, requiring you to forcefully physically reboot the system.


### java.io.IOException: Exceeded MAX_FAILED_UNIQUE_FETCHES;
```
java.io.IOException: Exceeded MAX_FAILED_UNIQUE_FETCHES;
bailing-out.
```

This cryptic exception basically translates to:
Could not communicate with  node(s). Tried to copy results between nodes but
we failed after to many retries.

Causes:
* some nodes cannot communicate between each other
* disturbed network
* some node terminated


###  Caused by: java.lang.InstantiationException: org.apache.hadoop.hive.ql.parse.ASTNodeOrigin ### 
OR

* https://issues.apache.org/jira/browse/HIVE-6765
* https://issues.apache.org/jira/browse/HIVE-5068

###  java.lang.Exception: XMLEncoder: discarding statement XMLEncoder.writeObject(MapredWork);
related to:
* Caused by: java.lang.InstantiationException: org.apache.hadoop.hive.ql.parse.ASTNodeOrigin

```
java.lang.RuntimeException: Cannot serialize object
    at org.apache.hadoop.hive.ql.exec.Utilities$1.exceptionThrown(Utilities.java:652)
Caused by: java.lang.Exception: XMLEncoder: discarding statement XMLEncoder.writeObject(MapredWork);
			...
```

* https://issues.apache.org/jira/browse/HIVE-5068


### FAILED: SemanticException [Error 10016]: Line 7:69 Argument type mismatch '0.0': The expression after ELSE should have the same type as those after THEN: "bigint" is expected but "double" is found
* https://issues.apache.org/jira/browse/HIVE-5825


### Error: GC overhead limit exceeded
```
Diagnostic Messages for this Task:
Error: GC overhead limit exceeded

FAILED: Execution Error, return code 2 from org.apache.hadoop.hive.ql.exec.mr.MapRedTask
```
Not enough (remote) mapper/reducer memory to complete the job.
You have to increase your mapper/reducer job memory limits (and/or yarn container limits).

Please read the chapter **cluster setup** from this FAQ section.

Note that this error is different from:
```
Execution failed with exit status: 3
FAILED: Execution Error, return code 3 from org.apache.hadoop.hive.ql.exec.mr.MapredLocalTask
```
as "Exit status: 3" indicates a memory overflow in the "LOCAL" jvm (the jvm that started your hive task) where as "Error, return code 2" indicates a "REMOTE" problem. (A jvm started by e.g. YARN on a Node to process your job)
