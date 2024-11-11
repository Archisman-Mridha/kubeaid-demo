FROM ubuntu:latest

RUN apt update

RUN \
	apt install -y jsonnet jq wget && \
# gojsontoyaml installation.
	wget https://github.com/brancz/gojsontoyaml/releases/download/v0.1.0/gojsontoyaml_0.1.0_linux_arm64.tar.gz && \
	tar -xvzf gojsontoyaml_0.1.0_linux_arm64.tar.gz && \
	chmod +x gojsontoyaml && \
	mkdir -p /usr/local/bin && \
	mv ./gojsontoyaml /usr/local/bin

CMD /kubeaid/build/kube-prometheus/build.sh /kubeaid-config/k8s/test.cluster.com
