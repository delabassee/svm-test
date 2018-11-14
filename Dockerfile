FROM fnproject/fn-java-fdk-build:latest as build
#LABEL maintainer="tomas.zezula@oracle.com"
WORKDIR /function
ENV MAVEN_OPTS=-Dmaven.repo.local=/usr/share/maven/ref/repository
ADD pom.xml pom.xml
RUN ["mvn", "package", "dependency:copy-dependencies", "-DincludeScope=runtime", "-DskipTests=true", "-Dmdep.prependGroupId=true", "-DoutputDirectory=target", "--fail-never"]
ADD src src
RUN ["mvn", "package"]

FROM fnproject/fn-java-native:latest as build-native-image
#LABEL maintainer="tomas.zezula@oracle.com"
WORKDIR /function

#COPY --from=openjdk:9-slim src/main/c/libfnunixsocket.so /function/runtime/lib/
#COPY src/main/c/libfnunixsocket.so /function/runtime/lib/
# /function/libfnunixsocket.so: /function/libfnunixsocket.so: cannot open shared object file: No such file or directory\n" 

COPY --from=build /function/target/*.jar target/
COPY --from=build /function/src/main/conf/reflection.json reflection.json
RUN /usr/local/graalvm/bin/native-image \
    --static \
    -H:Name=func \
    -H:+ReportUnsupportedElementsAtRuntime \
    -H:ReflectionConfigurationFiles=reflection.json \
    -H:+JNI \
    -classpath "target/*"\
    com.fnproject.fn.runtime.EntryPoint

#FROM scratch
#FROM alpine:3.8 #no libc!!
FROM busybox:glibc
#LABEL maintainer="tomas.zezula@oracle.com"
WORKDIR /function
COPY --from=build-native-image /function/func func
COPY src/main/c/libfnunixsocket.so /function/

ENTRYPOINT ["./func", "-XX:MaximumHeapSizePercent=80"]
CMD [ "com.example.fn.Hellosvm::handleRequest" ]
