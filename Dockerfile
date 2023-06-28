FROM ubuntu:latest

#copy the jar file
COPY ./stdEnrollment-0.0.1-SNAPSHOT.jar .

#install basic tools
RUN apt-get update
RUN apt install -y tar wget

#install Java JDK-20
RUN wget https://download.oracle.com/java/20/latest/jdk-20_linux-x64_bin.tar.gz
RUN tar zxvf jdk-20_linux-x64_bin.tar.gz
RUN mv jdk-20.0.1 /opt
ENV JAVA_HOME=/opt/jdk-20.0.1
ENV PATH=$JAVA_HOME/bin:$PATH
ENV CLASSPATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar