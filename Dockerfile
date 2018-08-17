FROM ubuntu:18.04

# packages
RUN apt-get update && apt-get install -yq --no-install-recommends \
    wget \
    git \
    gradle \
    debconf-utils \
    g++ \
    curl \
    build-essential \
    python3-pip python3-dev \
    software-properties-common && \
    add-apt-repository -y ppa:webupd8team/java && \
    apt-get update && \
    echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 select true" | \
    debconf-set-selections && \
    apt-get install -y oracle-java8-installer && \
    rm -rf /var/lib/apt/lists/*

RUN cd /usr/local/bin \
  && ln -s /usr/bin/python3 python \
  && pip3 install --upgrade pip

RUN mkdir app

ENV INSTALL_LOC /app

ENV SPARK_VERSION 2.2.2
ENV HADOOP_VERSION 2.7
ENV LIVY_VERSION 0.5.0-incubating

ENV SPARK_HOME $INSTALL_LOC/spark
ENV HAIL_HOME $INSTALL_LOC/hail
ENV LIVY_HOME $INSTALL_LOC/livy

RUN mkdir $INSTALL_LOC/hadoop-conf
ENV HADOOP_CONF_DIR $INSTALL_LOC/hadoop-conf

ENV SPARK_VERSION_STRING spark-$SPARK_VERSION-bin-hadoop$HADOOP_VERSION
ENV LIVY_VERSION_STRING livy-$LIVY_VERSION-bin

ENV SPARK_DOWNLOAD_URL ftp://apache.proserve.nl/apache/spark/spark-$SPARK_VERSION/$SPARK_VERSION_STRING.tgz
ENV LIVY_DOWNLOAD_URL ftp://apache.proserve.nl/apache/incubator/livy/$LIVY_VERSION/livy-$LIVY_VERSION-bin.zip
ENV HAIL_DOWNLOAD_URL https://github.com/hail-is/hail.git

ENV PYTHONPATH "$PYTHONPATH:$HAIL_HOME/python:$SPARK_HOME/python:`echo $SPARK_HOME/python/lib/py4j*-src.zip`"
ENV SPARK_CLASSPATH $HAIL_HOME/build/libs/hail-all-spark.jar
ENV PYSPARK_SUBMIT_ARGS "\
      --jars $HAIL_HOME/build/libs/hail-all-spark.jar \
      --conf spark.driver.extraClassPath=\"$HAIL_HOME/build/libs/hail-all-spark.jar\" \
      --conf spark.executor.extraClassPath=./hail-all-spark.jar \
      --conf spark.serializer=org.apache.spark.serializer.KryoSerializer \
      --conf spark.kryo.registrator=is.hail.kryo.HailKryoRegistrator \
      pyspark-shell"

# Download and unzip Spark
RUN mkdir -p $SPARK_HOME
RUN wget -nv $SPARK_DOWNLOAD_URL
RUN tar -xvzf $SPARK_VERSION_STRING.tgz -C /tmp
RUN cp -rf /tmp/$SPARK_VERSION_STRING/* $SPARK_HOME
RUN rm -rf /tmp/$SPARK_VERSION_STRING
RUN rm $SPARK_VERSION_STRING.tgz

RUN ls && ls $INSTALL_LOC

RUN mkdir -p $HAIL_HOME
RUN git clone $HAIL_DOWNLOAD_URL $HAIL_HOME
WORKDIR $HAIL_HOME
RUN ./gradlew -Dspark.version=2.2.0 shadowJar
WORKDIR /

RUN mkdir -p $LIVY_HOME
RUN wget -nv $LIVY_DOWNLOAD_URL
RUN unzip $LIVY_VERSION_STRING.zip -d /tmp
RUN cp -rf /tmp/$LIVY_VERSION_STRING/* $LIVY_HOME
RUN rm -rf /tmp/$LIVY_VERSION_STRING
RUN rm $LIVY_VERSION_STRING.zip
RUN mkdir -p $LIVY_HOME/logs

RUN pip3 install --upgrade pip setuptools
RUN pip3 install numpy pandas matplotlib seaborn bokeh jupyter pip parsimonious==0.8.0 ipykernel decorator==4.2.1

# Add custom files, set permissions
ADD entrypoint.sh .
RUN chmod +x entrypoint.sh
# Expose port
EXPOSE 8998

RUN echo $SPARK_CLASSPATH
RUN ls /app/hail/build/libs/

ENTRYPOINT ["./entrypoint.sh"]



























