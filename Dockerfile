FROM amazonlinux:2

# Set up working directories
RUN mkdir -p /opt/app && \
    mkdir -p /opt/app/build && \
    mkdir -p /opt/app/bin/

# Copy in the lambda source
WORKDIR /opt/app
COPY ./*.py /opt/app/
COPY requirements.txt /opt/app/requirements.txt

# Install packages
RUN yum update -y && \
    amazon-linux-extras install epel -y && \
    yum install -y cpio yum-utils tar.x86_64 gzip zip python3-pip gcc openssl-devel bzip2-devel libffi-devel wget tar && \
    yum groupinstall -y "Development Tools"

RUN cd /opt && wget https://www.python.org/ftp/python/3.9.23/Python-3.9.23.tgz && tar xzf Python-3.9.23.tgz && \
    cd Python-3.9.23 && ./configure --enable-shared --enable-optimizations && make altinstall && \
    rm -f /usr/bin/python3 && ln -s /usr/local/bin/python3.9 /usr/bin/python3 && \
    rm -f /usr/bin/pip3 && ln -s /usr/local/bin/pip3.9 /usr/bin/pip3 && \
    rm -rf /opt/Python-3.9.23* && ldconfig

ENV LD_LIBRARY_PATH=/usr/local/lib:/usr/local/lib64

ENV PATH="$PATH:/usr/local/bin"

RUN python3.9 -V
# This had --no-cache-dir, tracing through multiple tickets led to a problem in wheel
RUN pip3.9 install -r requirements.txt && \
    rm -rf /root/.cache/pip

# Download libraries we need to run in lambda
WORKDIR /tmp
RUN yumdownloader -x \*i686 --archlist=x86_64 \
    clamav \
    clamav-lib \
    clamav-update \
    json-c \
    pcre2 \
    libtool-ltdl \
    libxml2 \
    bzip2-libs \
    xz-libs \
    libprelude \
    gnutls \
    nettle && \
    rpm2cpio clamav-0*.rpm | cpio -vimd && \
    rpm2cpio clamav-lib*.rpm | cpio -vimd && \
    rpm2cpio clamav-update*.rpm | cpio -vimd && \
    rpm2cpio json-c*.rpm | cpio -vimd && \
    rpm2cpio pcre*.rpm | cpio -vimd && \
    rpm2cpio libtool-ltdl*.rpm | cpio -vimd && \
    rpm2cpio libxml2*.rpm | cpio -vimd && \
    rpm2cpio bzip2-libs*.rpm | cpio -vimd && \
    rpm2cpio xz-libs*.rpm | cpio -vimd && \
    rpm2cpio libprelude*.rpm | cpio -vimd && \
    rpm2cpio gnutls*.rpm | cpio -vimd && \
    rpm2cpio nettle*.rpm | cpio -vimd


# Copy over the binaries and libraries
RUN cp /tmp/usr/bin/clamscan /tmp/usr/bin/freshclam /tmp/usr/lib64/* /usr/lib64/libpcre.so.1 /opt/app/bin/

# Fix the freshclam.conf settings
RUN echo "DatabaseMirror database.clamav.net" > /opt/app/bin/freshclam.conf
RUN echo "CompressLocalDatabase yes" >> /opt/app/bin/freshclam.conf
RUN echo "ScriptedUpdates no" >> /opt/app/bin/freshclam.conf
RUN echo "DatabaseDirectory /var/lib/clamav" >> /opt/app/bin/freshclam.conf

RUN yum install shadow-utils.x86_64 -y

RUN groupadd clamav && \
    useradd -g clamav -s /bin/false -c "Clam Antivirus" clamav && \
    useradd -g clamav -s /bin/false -c "Clam Antivirus" clamupdate

ENV LD_LIBRARY_PATH=/opt/app/bin:/usr/local/lib:/usr/local/lib64
RUN ldconfig

# Create the zip file
WORKDIR /opt/app
RUN zip -r9 --exclude="*test*" /opt/app/build/lambda.zip *.py bin

WORKDIR /usr/local/lib/python3.9/site-packages
RUN zip -r9 /opt/app/build/lambda.zip *

WORKDIR /opt/app
