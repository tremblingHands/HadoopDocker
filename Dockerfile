FROM ubuntu:16.04

WORKDIR /root

COPY sources.list etc/apt/sources.list

RUN apt-get update && apt-get install -y ssh rsync openjdk-8-jdk vim

COPY hadoop-3.1.1.tar /root
RUN tar xvf hadoop-3.1.1.tar && \
    mv hadoop-3.1.1 /usr/local/hadoop 

ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-arm64/
ENV HADOOP_HOME=/usr/local/hadoop 
ENV PATH=$PATH:/usr/local/hadoop/bin:/usr/local/hadoop/sbin 

# ssh without key
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

