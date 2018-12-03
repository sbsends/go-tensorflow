# GOLANG BASE IMAGE -- MUST VERSION
FROM golang:1.11.1-stretch as builder

# SET UP WORKSPACE (GO IDIOMATIC)
ADD . /go/src/github.com/sbsends/go-tensorflow
WORKDIR /go/src/github.com/sbsends/go-tensorflow

# SET ENV VARIABLES (MOD, PROOT, ARCH, GOOS) 
ENV GO111MODULE=on
ENV PROJECT_ROOT=train
ENV GOARCH=amd64
ENV GOOS=linux

# DOWNLOAD TF LIBRARY AND UPDATE LINKER
# NOTE: SWITCH TO GPU LIB TO SUPPORT GPU ACCELERATION
RUN wget https://storage.googleapis.com/tensorflow/libtensorflow/libtensorflow-cpu-linux-x86_64-1.12.0.tar.gz
RUN tar -xz -f libtensorflow-cpu-linux-x86_64-1.12.0.tar.gz -C /usr/local
RUN ldconfig

# BUILD THE BINARY (WITHOUT DEBUG)
RUN go build -o train

# ALPINE CA-CERTS
FROM alpine:latest as certs
RUN apk --update add ca-certificates

# SCRATCH (VERY SLIM IMAGE)
FROM scratch

# COPY OVER CA-CERTIFICATES FROM ALPINE
COPY --from=certs /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

# COPY GO BINARY AND GRAPH PROTOBUF
COPY --from=builder /go/src/github.com/sbsends/go-tensorflow/train .
COPY --from=builder /go/src/github.com/sbsends/go-tensorflow/graph.pb .

# COPY OVER SHARED LIBRARIES THAT THE DYNAMIC BINARY DEPENDS ON.
COPY --from=builder /usr/local/lib/libtensorflow.so /usr/local/lib/libtensorflow.so
COPY --from=builder /usr/local/include /usr/local/include
COPY --from=builder /lib/x86_64-linux-gnu/libpthread.so.0 /lib/x86_64-linux-gnu/libpthread.so.0
COPY --from=builder /lib/x86_64-linux-gnu/libc.so.6 /lib/x86_64-linux-gnu/libc.so.6
COPY --from=builder /usr/local/lib/libtensorflow_framework.so /usr/local/lib/libtensorflow_framework.so
COPY --from=builder /lib/x86_64-linux-gnu/libdl.so.2 /lib/x86_64-linux-gnu/libdl.so.2
COPY --from=builder /lib/x86_64-linux-gnu/libm.so.6 /lib/x86_64-linux-gnu/libm.so.6
COPY --from=builder /lib/x86_64-linux-gnu/librt.so.1 /lib/x86_64-linux-gnu/librt.so.1
COPY --from=builder /usr/lib/x86_64-linux-gnu/libstdc++.so.6 /usr/lib/x86_64-linux-gnu/libstdc++.so.6
COPY --from=builder /lib/x86_64-linux-gnu/libgcc_s.so.1 /lib/x86_64-linux-gnu/libgcc_s.so.1
COPY --from=builder /lib64/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2

# ADD /USR/LIB & USR/LOCAL/LIB (NOT A SCRATCH DEFAULT)
ENV LD_LIBRARY_PATH /usr/lib/:/usr/local/lib

# RUN BINARY
ENTRYPOINT ["./train"]