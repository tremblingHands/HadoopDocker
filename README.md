
# HADOOP

## 参考

Spark on Yarn集群搭建详细过程
https://www.jianshu.com/p/aa6f3a366727

Hadoop的HA机制(Zookeeper集群+Hadoop集群)配置记录
https://blog.csdn.net/dingchenxixi/article/details/51131493

spark分布式集群环境搭建（hadoop之上）
https://blog.csdn.net/moledyzhang/article/details/78843746

kafka集群搭建
https://www.cnblogs.com/luotianshuai/p/5206662.html

Spark 实战, 第 2 部分:使用 Kafka 和 Spark Streaming 构建实时数据处理系统
https://www.ibm.com/developerworks/cn/opensource/os-cn-spark-practice2/index.html


## hadoop镜像制作及运行

### Dokcerfile

```bash
FROM ubuntu:16.04

WORKDIR /root

COPY sources.list etc/apt/sources.list

RUN apt-get update && apt-get install -y ssh rsync openjdk-8-jdk vim

COPY hadoop-3.1.1.tar /root
RUN tar xvf hadoop-3.1.1.tar && \
    mv hadoop-3.1.1 /usr/local/hadoop 

ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/
ENV HADOOP_HOME=/usr/local/hadoop 
ENV PATH=$PATH:/usr/local/hadoop/bin:/usr/local/hadoop/sbin 

RUN ssh-keygen -t rsa -f ~/.ssh/id_rsa -P '' && \
    cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys


COPY config/* /tmp/

RUN mv /tmp/ssh_config ~/.ssh/config && \
    mv /tmp/hadoop-env.sh /usr/local/hadoop/etc/hadoop/hadoop-env.sh && \
    mv /tmp/hdfs-site.xml $HADOOP_HOME/etc/hadoop/hdfs-site.xml && \ 
    mv /tmp/core-site.xml $HADOOP_HOME/etc/hadoop/core-site.xml && \
    mv /tmp/mapred-site.xml $HADOOP_HOME/etc/hadoop/mapred-site.xml && \
    mv /tmp/yarn-site.xml $HADOOP_HOME/etc/hadoop/yarn-site.xml && \
    mv /tmp/start-dfs.sh $HADOOP_HOME/sbin/start-dfs.sh && \
    mv /tmp/start-yarn.sh $HADOOP_HOME/sbin/start-yarn.sh && \
    mv /tmp/stop-dfs.sh $HADOOP_HOME/sbin/stop-dfs.sh && \
    mv /tmp/stop-yarn.sh $HADOOP_HOME/sbin/stop-yarn.sh
    
RUN chmod +x $HADOOP_HOME/sbin/start-dfs.sh && \
    chmod +x $HADOOP_HOME/sbin/start-yarn.sh 
    
CMD [ "sh", "-c", "service ssh start; bash"]

```
### 生成镜像

```
docker build -t myhadoop
```

### 运行容器


```bash
docker network create --driver=bridge hadoop

#运行master节点
docker run -it \
                --net=hadoop \
                -p 50070:50070 \
                -p 8088:8088 \
                --name hadoop-master \
                --hostname hadoop-master \
                myhadoop \
                bash

#运行slave节点
docker run -it\
                        --net=hadoop \
                        --name hadoop-slave1 \
                        --hostname hadoop-slave1 \
                        myhadoop \
                        bash

#进入容器后执行以下操作
service ssh start 
#修改集群成员，例如加入hadoop-master,hadoop-slave1
echo "hadoop-master" > $HADOOP_HOME/etc/hadoop
echo "hadoop-slave1" >> $HADOOP_HOME/etc/hadoop
```

### 配置文件如下，都存放于config目录下


* core-site.xml

```
<configuration>
        <property>
        #hadoop使用的文件系统(uri) hdfs 和hdfs的位置
            <name>fs.defaultFS</name>
            <value>hdfs://hadoop-master:9000</value>
        </property>
        <property>
        #hadoop运行时产生的文件的存储位置
            <name>hadoop.tmp.dir</name>
            <value>/export/data/HADOOP/apps/hadoop-3.1.1/tmp</value>
        </property>
</configuration>
```

* hdfs-site.xml

```
<configuration>
    ----------------
    <property>
    #namenode上存储hdfs名字空间元数据
        <name>dfs.namenode.name.dir</name>
        <value>/export/data/HADOOP/hdfs/name</value>
    </property>
    <property>
    #hdfs datanode上数据块的物理存储位置
        <name>dfs.datanode.data.dir</name>
        <value>/export/data/HADOOP/hdfs/data</value>
    </property>
    <property>
    #hdfs数据副本数量 3分副本 应小于datanode机器数量
        <name>dfs.replication</name>
        <value>3</value>
    </property>
</configuration>
```

* mapred-site.xml

```
<configuration>
  <property>
      <name>mapreduce.framework.name</name>
      <value>yarn</value>
  </property>
  <property>
    <name>mapreduce.map.memory.mb</name>
    <value>2048</value>
  </property>
  <property>
    <name>mapreduce.reduce.memory.mb</name>
    <value>2048</value>
  </property>
  <property>
    <name>mapreduce.map.java.opts</name>
    <value>-Xmx1024m</value>
  </property>
  <property>
    <name>mapreduce.reduce.java.opts</name>
    <value>-Xmx1024m</value>
  </property>
  <property>
      <name>yarn.app.mapreduce.am.env</name>
      <value>HADOOP_MAPRED_HOME=/usr/local/hadoop</value>
  </property>
  <property>
      <name>mapreduce.map.env</name>
      <value>HADOOP_MAPRED_HOME=/usr/local/hadoop</value>
  </property>
  <property>
      <name>mapreduce.reduce.env</name>
      <value>HADOOP_MAPRED_HOME=/usr/local/hadoop</value>
  </property>
  <property>
      <name>mapreduce.application.classpath</name>
      <value>$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/*,$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/lib/*,$HADOOP_MAPRED_HOME/share/hadoop/common/*,$HADOOP_MAPRED_HOME/share/hadoop/common/lib/*,$HADOOP_MAPRED_HOME/share/hadoop/yarn/*,$HADOOP_MAPRED_HOME/share/hadoop/yarn/lib/*,$HADOOP_MAPRED_HOME/share/hadoop/hdfs/*,$HADOOP_MAPRED_HOME/share/hadoop/hdfs/lib/*</value>
  </property>
</configuration>

```

* yarn-site.xml

```
<configuration>
<!-- Site specific YARN configuration properties -->
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
    <property>
        <name>yarn.resourcemanager.hostname</name>
        <value>hadoop-master</value>
    </property>
</configuration>
```

* ~/.ssh/config

```
Host localhost
  StrictHostKeyChecking no

Host 0.0.0.0
  StrictHostKeyChecking no

Host hadoop-*
   StrictHostKeyChecking no
   UserKnownHostsFile=/dev/null
```

## 遇到的问题及解决方案


```bash
ERROR: java_home not set
 
vim  etc/hadoop/hadoop-env.sh
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/
```
```
ERROR: Attempting to launch hdfs namenode as root 
ERROR: but there is no HDFS_NAMENODE_USER defined. Aborting launch. 

vim sbin/start-dfs.sh 
vim sbin/stop-dfs.sh 
在顶部空白处添加内容： 
HDFS_DATANODE_USER=root 
HADOOP_SECURE_DN_USER=hdfs 
HDFS_NAMENODE_USER=root 
HDFS_SECONDARYNAMENODE_USER=root 
```
```
ERROR: Name node is in safe mode 

bin/hadoop dfsadmin -safemode leave 
```

```
Starting resourcemanager
ERROR: Attempting to operate on yarn resourcemanager as root
ERROR: but there is no YARN_RESOURCEMANAGER_USER defined. Aborting operation.
Starting nodemanagers
ERROR: Attempting to operate on yarn nodemanager as root
ERROR: but there is no YARN_NODEMANAGER_USER defined. Aborting operation.

是因为缺少用户定义造成的，所以分别编辑开始和关闭脚本 
vim sbin/start-yarn.sh 
vim sbin/stop-yarn.sh 

YARN_RESOURCEMANAGER_USER=root
YARN_NODEMANAGER_USER=root
HDFS_DATANODE_SECURE_USER=yarn
HDFS_DATANODE_USER=root
HDFS_NAMENODE_USER=root
HDFS_SECONDARYNAMENODE_USER=root



export HDFS_NAMENODE_USER=root
export HDFS_DATANODE_USER=root
export HDFS_SECONDARYNAMENODE_USER=root
 
export YARN_RESOURCEMANAGER_USER=root
export YARN_NODEMANAGER_USER=root

```


```
Call From slaver1/127.0.0.1 to master:9000 failed on connection exception: java.net.ConnectException: Connection refused

Check that there isn't an entry for your hostname mapped to 127.0.0.1 or 127.0.1.1 in /etc/hosts (Ubuntu is notorious for this)
```


```
vi etc/hadoop/mapred-site.xml
<configuration>
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>
</configuration>
 
<configuration>
    <property>
        <name>mapreduce.application.classpath</name>
        <value>$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/*:$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/lib/*</value>
    </property>
</configuration>


vi etc/hadoop/yarn-site.xml
<configuration>
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
    <property>
        <name>yarn.nodemanager.env-whitelist</name>
        <value>JAVA_HOME,HADOOP_COMMON_HOME,HADOOP_HDFS_HOME,HADOOP_CONF_DIR,CLASSPATH_PREPEND_DISTCACHE,HADOOP_YARN_HOME,HADOOP_MAPRED_HOME</value>
    </property>
</configuration>


<configuration>
  <property>
      <name>mapreduce.framework.name</name>
      <value>yarn</value>
  </property>
  <property>
      <name>yarn.app.mapreduce.am.env</name>
      <value>HADOOP_MAPRED_HOME=/usr/local/hadoop</value>
  </property>
  <property>
      <name>mapreduce.map.env</name>
      <value>HADOOP_MAPRED_HOME=/usr/local/hadoop</value>
  </property>
  <property>
      <name>mapreduce.reduce.env</name>
      <value>HADOOP_MAPRED_HOME=/usr/local/hadoop</value>
  </property>
  <property>
      <name>mapreduce.application.classpath</name>
      <value>$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/*,$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/lib/*,$HADOOP_MAPRED_HOME/share/hadoop/common/*,$HADOOP_MAPRED_HOME/share/hadoop/common/lib/*,$HADOOP_MAPRED_HOME/share/hadoop/yarn/*,$HADOOP_MAPRED_HOME/share/hadoop/yarn/lib/*,$HADOOP_MAPRED_HOME/share/hadoop/hdfs/*,$HADOOP_MAPRED_HOME/share/hadoop/hdfs/lib/*</value>
  </property>
</configuration>



```


## 测试hadoop集群

在 master 上进行如下操作

```bash
#初始化
hdfs namenode -format 
#启动HDFS和yarn
start-all.sh 

#在hdfs中创建目录
hdfs dfs -mkdir -p /user/root/input
#将输入文件上传到hdfs
hdfs dfs -put etc/hadoop/*.xml input
#启动应用，将输入文件作为执行参数
hadoop jar share/hadoop/mapreduce/hadoop-mapreduce-examples-3.1.1.jar grep input output 'dfs[a-z.]+'
```

日志如下

```
2018-10-27 06:35:17,680 INFO mapreduce.Job: Running job: job_1540622073956_0002
2018-10-27 06:35:29,849 INFO mapreduce.Job: Job job_1540622073956_0002 running in uber mode : false
2018-10-27 06:35:29,849 INFO mapreduce.Job:  map 0% reduce 0%
2018-10-27 06:35:35,904 INFO mapreduce.Job:  map 100% reduce 0%
2018-10-27 06:35:42,951 INFO mapreduce.Job:  map 100% reduce 100%
2018-10-27 06:35:43,966 INFO mapreduce.Job: Job job_1540622073956_0002 completed successfully
2018-10-27 06:35:44,015 INFO mapreduce.Job: Counters: 53
	File System Counters
		FILE: Number of bytes read=97
		FILE: Number of bytes written=429957
		FILE: Number of read operations=0
		FILE: Number of large read operations=0
		FILE: Number of write operations=0
		HDFS: Number of bytes read=331
		HDFS: Number of bytes written=59
		HDFS: Number of read operations=9
		HDFS: Number of large read operations=0
		HDFS: Number of write operations=2
	Job Counters 
		Launched map tasks=1
		Launched reduce tasks=1
		Data-local map tasks=1
		Total time spent by all maps in occupied slots (ms)=4003
		Total time spent by all reduces in occupied slots (ms)=4045
		Total time spent by all map tasks (ms)=4003
		Total time spent by all reduce tasks (ms)=4045
		Total vcore-milliseconds taken by all map tasks=4003
		Total vcore-milliseconds taken by all reduce tasks=4045
		Total megabyte-milliseconds taken by all map tasks=4099072
		Total megabyte-milliseconds taken by all reduce tasks=4142080
	Map-Reduce Framework
		Map input records=4
		Map output records=4
		Map output bytes=83
		Map output materialized bytes=97
		Input split bytes=130
		Combine input records=0
		Combine output records=0
		Reduce input groups=1
		Reduce shuffle bytes=97
		Reduce input records=4
		Reduce output records=4
		Spilled Records=8
		Shuffled Maps =1
		Failed Shuffles=0
		Merged Map outputs=1
		GC time elapsed (ms)=295
		CPU time spent (ms)=2670
		Physical memory (bytes) snapshot=666013696
		Virtual memory (bytes) snapshot=5386706944
		Total committed heap usage (bytes)=1245708288
		Peak Map Physical memory (bytes)=361017344
		Peak Map Virtual memory (bytes)=2689245184
		Peak Reduce Physical memory (bytes)=304996352
		Peak Reduce Virtual memory (bytes)=2697461760
	Shuffle Errors
		BAD_ID=0
		CONNECTION=0
		IO_ERROR=0
		WRONG_LENGTH=0
		WRONG_MAP=0
		WRONG_REDUCE=0
	File Input Format Counters 
		Bytes Read=201
	File Output Format Counters 
		Bytes Written=59
```

查看执行结果

```
hdfs dfs -cat output/*
```
```
1	dfsadmin
1	dfs.replication
1	dfs.name.dir
1	dfs.data.dir
```



# 安装 scala spark


```
1.在官网下载scala安装包，http://www.scala-lang.org/download/
2.将下载的压缩包解压到/opt/scala中

sudo mkdir /opt/scala
sudo tar -zxvf scala-2.11.8.tgz -C /opt/scala
3.设置环境变量
sudo vim ~/.bashrc
在文件最后添加
export PATH=/opt/scala/scala-2.11.8/bin:$PATH
（如果是在终端中打开，按A编辑后，ESC，输入"：wq"退出）
4.验证
输入scala -version 检查版本是否有误

```

```
1.在官网下载spark安装包，http://spark.apache.org/downloads.html
2.将下载的压缩包解压到/usr/local/spark/中

sudo mkdir /usr/local/spark/
sudo tar -zxvf spark-2.3.2-bin-hadoop2.7.tgz -C /usr/local/spark/
3.设置环境变量
sudo vim ~/.bashrc
在文件最后添加
export SPARK_HOME=/usr/local/spark/spark-2.3.2-bin-hadoop2.7
export PATH=${SPARK_HOME}/bin:$PATH
4.验证
输入pyspark --version 检查版本是否有误
```


# SPARK

## 使用 spark-submit 运行应用

### 说明

Once a user application is bundled, it can be launched using the bin/spark-submit script. This script takes care of setting up the classpath with Spark and its dependencies, and can support different cluster managers and deploy modes that Spark supports:

```
./bin/spark-submit \
  --class <main-class> \
  --master <master-url> \
  --deploy-mode <deploy-mode> \
  --conf <key>=<value> \
  ... # other options
  <application-jar> \
  [application-arguments]
```

Some of the commonly used options are:

* --class: The entry point for your application (e.g. org.apache.spark.examples.SparkPi)
* --master: The master URL for the cluster (e.g. spark://23.195.26.187:7077)
* --deploy-mode: Whether to deploy your driver on the worker nodes (cluster) or locally as an external client (client) (default: client) †
* --conf: Arbitrary Spark configuration property in key=value format. For values that contain spaces wrap “key=value” in quotes (as shown).
* application-jar: Path to a bundled jar including your application and all dependencies. The URL must be globally visible inside of your cluster, for instance, an hdfs:// path or a file:// path that is present on all nodes.
* application-arguments: Arguments passed to the main method of your main class, if any

### 配置及启动SPARK

```bash
cd $SPARK_HOME

#添加启动环境
vim conf/spark-env.sh 
export SPARK_MASTER_IP=hadoop-master
export SPARK_WORKER_MEMORY=128m
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-arm64/
export SCALA_HOME=/opt/scala/scala-2.11.8
export SPARK_HOME=/usr/local/spark/spark-2.3.2-bin-hadoop2.7
export HADOOP_CONF_DIR=/usr/local/hadoop/etc/hadoop
export SPARK_LIBRARY_PATH=$SPARK_HOME/lib
export SCALA_LIBRARY_PATH=$SPARK_LIBRARY_PATH
export SPARK_WORKER_CORES=1
export SPARK_WORKER_INSTANCES=1
export SPARK_MASTER_PORT=7077

#添加slave节点
vim conf/slaves
hadoop-slave1

#启动SPARK
sbin/start-all.sh
```

### 测试

```bash
#可以通过页面查看SPARK管理信息 http://ip:8080

#使用spark-submit提交任务
./bin/spark-submit --class org.apache.spark.examples.SparkPi --master yarn --deploy-mode cluster --executor-memory 1G --executor-cores 2 examples/jars/spark-examples_2.11-2.3.2.jar  40
#执行成功
final status: SUCCEEDED


#将Hadoop集群上的文件作为测试参数
#创建输入文件1.txt
vim 1.txt
hello spark
hello word
hello spark

#上传输入文件
hdfs dfs -put 1.txt /tmp
#打开spark-shell
spark-shell

#创建文件描述符
val readmeFile = sc.textFile("hdfs://hadoop-master:9000/tmp/1.txt")
#获取文件行数
readmeFile.count
res1: Long = 3

var theCount = readmeFile.filter(line=>line.contains("spark"))
theCount.count
res2: Long = 2

var wordCount = readmeFile.flatMap(line=>line.split(" ")).map(word=>(word,1)).reduceByKey(_+_)
 wordCount.collect
res3: Array[(String, Int)] = Array((word,1), (hello,3), (spark,2))

```


```bash
#将zookeeper kafka 导入容器中
docker cp zookeeper-3.4.12 containerID:~/zookeeper
docker cp kafka_2.11-2.0.0 containerID:~/kafka

#保存容器
docker commit containerID kafka:v1
```



# 启动zookeeper

```bash
docker network create --driver=bridge kafka

docker run -it --name server1 --hostname server1 --net kafka kafka:v1 bash
```
在每个容器下进行如下操作

```bash
#修改zookeeper配置文件
vim zookeeper/conf/zoo.cfg 
dataDir=/root/zookeeper/data
dataLogDir=/root/zookeeper/log
server.1=server1:2888:3888
server.2=server2:2888:3888
server.3=server3:2888:3888

#server1的myid配置为1，server2的myid配置为2，server3的myid配置为3，
vim zookeeper/data/myid 
1

#配置ssh
vim ~/.ssh/config 
Host server*
   StrictHostKeyChecking no
   UserKnownHostsFile=/dev/null

service ssh start

#启动zookeeper（每个容器都要启动zookeeper）
zookeeper/bin/zkServer.sh start
zookeeper/bin/zkServer.sh status

```

# 启动kafka

在每个容器下进行如下操作

```bash
#配置kafka
vim kafka/config/server.properties 
#每个容器的broker.id不同
broker.id=0
message.max.byte=5242880
default.replication.factor=2
replica.fetch.max.bytes=5242880
#zookeeper.connect 配置为zookeeper的ip:port
zookeeper.connect=172.19.0.2:2181,172.19.0.3:2181,172.19.0.4:2181
```

### 测试

```bash
cd kafka

#查看当前topic
bin/kafka-topics.sh --list --zookeeper 172.19.0.2:2181
test

##其中一个容器作为生产者，一个容器作为消费者，分别执行以下命令
#生产者
bin/kafka-console-producer.sh --broker-list 172.19.0.2:9092 --topic test
>hello world
>wahaha
>hello

#消费者
bin/kafka-console-consumer.sh --bootstrap-server 172.19.0.2:9092 --topic test --from-beginning
hello world
wahaha
hello

```

### spark使用kafaka

```bash
https://www.ibm.com/developerworks/cn/opensource/os-cn-spark-practice2/index.html

#示例
bin/spark-submit \
--jars $SPARK_HOME/lib/spark-streaming-kafka_2.10-1.3.1.jar, \
$SPARK_HOME/lib/spark-streaming-kafka-assembly_2.10-1.3.1.jar, \
$SPARK_HOME/lib/kafka_2.10-0.8.2.1.jar, \
$SPARK_HOME/lib/kafka-clients-0.8.2.1.jar \ 
--class com.ibm.spark.exercise.streaming.WebPagePopularityValueCalculator 
--master spark://<spark_master_ip>:7077 \
--num-executors 4 \
--driver-memory 4g \
--executor-memory 2g \
--executor-cores 2 \
/home/fams/sparkexercise.jar \
192.168.1.1:2181,192.168.1.2:2181,192.168.1.3:2181 2
```
