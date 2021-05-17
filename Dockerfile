#
# GitLab CI: Android v0.1
#
# https://hub.docker.com/r/infoware/gitlab-ci-android-r18b/
#

FROM ubuntu:18.04
MAINTAINER infoware <github@infoware.de>

# must be updated in case of new versions
ENV ANDROID_NDK_VERSION r18b

# must be updated in case of new versions
ENV VERSION_SDK_TOOLS=6858069

ENV ANDROID_NDK_HOME /opt/android-ndk
ENV ANDROID_HOME "/sdk"
ENV ANDROID_SDK_ROOT="/sdk"

ENV PATH "$PATH:${ANDROID_HOME}/tools"
ENV DEBIAN_FRONTEND noninteractive

# Special files to have always the same debug certificates otherwise they might be different for each running docker
# which makes it more difficult to start automatic tests
#ADB RSA HASH - https://github.com/sorccu/docker-adb/blob/master/Dockerfile
# Set up insecure default key
RUN mkdir -m 0750 /root/.android
ADD files/insecure_shared_adbkey /root/.android/adbkey
ADD files/insecure_shared_adbkey.pub /root/.android/adbkey.pub

# install all needed linux packges
RUN apt-get -qq update && \
    apt-get install -qqy --no-install-recommends \
      bzip2 \
      curl \
      git-core \
      html2text \
      openjdk-8-jdk \
      libc6-i386 \
      lib32stdc++6 \
      lib32gcc1 \
      lib32ncurses5 \
      lib32z1 \
      unzip \
      openssh-client \
      sshpass \
      ftp \
      lftp \
      doxygen \
      doxygen-latex \
      graphviz \
      wget \
      build-essential \
      ccache \
      joe \
      maven \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN rm -f /etc/ssl/certs/java/cacerts; \
    /var/lib/dpkg/info/ca-certificates-java.postinst configure
    

# GitLab injects the username as ENV-variable which will crash a gradle-build.
# Workaround by adding unicode-support.
# See
# https://github.com/gradle/gradle/issues/3117#issuecomment-336192694
# https://github.com/tianon/docker-brew-debian/issues/45
RUN apt-get update && apt-get install -y locales && rm -rf /var/lib/apt/lists/* \
	&& localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.UTF-8

###################################
# Android SDK

# Download current command line tools
RUN curl -s "https://dl.google.com/android/repository/commandlinetools-linux-${VERSION_SDK_TOOLS}_latest.zip" -o /sdk.zip
RUN unzip /sdk.zip -d /sdk
RUN rm -v /sdk.zip

# Download current Platform tools
RUN curl -s https://dl.google.com/android/repository/platform-tools_r31.0.2-linux.zip > /sdk/platform-tools.zip && \
    unzip /sdk/platform-tools.zip -d /sdk 

RUN mkdir -p $ANDROID_HOME/licenses/ \
  && echo "8933bad161af4178b1185d1a37fbf41ea5269c55\nd56f5187479451eabf01fb78af6dfcb131a6481e" > $ANDROID_HOME/licenses/android-sdk-license \
  && echo "84831b9409646a918e30573bab4c9c91346d8abd\n504667f4c0de7af1a06de9f4b1727b84351f2910" > $ANDROID_HOME/licenses/android-sdk-preview-license

ADD packages.txt /sdk
RUN echo "2" | update-alternatives --config java

RUN mkdir -p /root/.android && \
  touch /root/.android/repositories.cfg && \
  ${ANDROID_HOME}/cmdline-tools/bin/sdkmanager --update --sdk_root=/sdk

RUN while read -r package; do PACKAGES="${PACKAGES}${package} "; done < /sdk/packages.txt && \
    ${ANDROID_HOME}/cmdline-tools/bin/sdkmanager ${PACKAGES} --sdk_root=/sdk

# accept all licences
RUN yes | ${ANDROID_HOME}/cmdline-tools/bin/sdkmanager --licenses --sdk_root=/sdk

RUN mkdir scripts
ADD get-release-notes.sh /scripts
RUN chmod +x /scripts/get-release-notes.sh
ADD adb-all.sh /scripts
RUN chmod +x /scripts/adb-all.sh
ADD compare_files.sh /scripts
RUN chmod +x /scripts/compare_files.sh
ADD lint-up.rb /scripts
ADD send_ftp.sh /scripts



# ------------------------------------------------------
# --- Android NDK

# download
RUN mkdir /opt/android-ndk-tmp
RUN cd /opt/android-ndk-tmp
RUN wget -q https://dl.google.com/android/repository/android-ndk-${ANDROID_NDK_VERSION}-linux-x86_64.zip
# uncompress
RUN unzip -q android-ndk-${ANDROID_NDK_VERSION}-linux-x86_64.zip
# move to its final location
RUN mv ./android-ndk-${ANDROID_NDK_VERSION} ${ANDROID_NDK_HOME}
# remove temp dir
RUN cd ${ANDROID_NDK_HOME}
RUN rm -rf /opt/android-ndk-tmp

# add to PATH
ENV PATH ${PATH}:${ANDROID_NDK_HOME}

# SETTINGS FOR GRADLE 5.1.1
ADD https://services.gradle.org/distributions/gradle-5.1.1-all.zip /tmp
RUN mkdir -p /opt/gradle/gradle-5.1.1/wrapper/dists/gradle-5.1.1-all/97z1ksx6lirer3kbvdnh7jtjg
RUN cp /tmp/gradle-5.1.1-all.zip /opt/gradle/gradle-5.1.1/wrapper/dists/gradle-5.1.1-all/97z1ksx6lirer3kbvdnh7jtjg/
RUN unzip /tmp/gradle-5.1.1-all.zip -d /opt/gradle/gradle-5.1.1/wrapper/dists/gradle-5.1.1-all/97z1ksx6lirer3kbvdnh7jtjg
RUN touch /opt/gradle/gradle-5.1.1/wrapper/dists/gradle-5.1.1-all/97z1ksx6lirer3kbvdnh7jtjg/gradle-5.1.1-all.ok
RUN touch /opt/gradle/gradle-5.1.1/wrapper/dists/gradle-5.1.1-all/97z1ksx6lirer3kbvdnh7jtjg/gradle-5.1.1-all.lck
#RUN /opt/gradle/gradle-5.1.1/wrapper/dists/gradle-5.1.1-all/97z1ksx6lirer3kbvdnh7jtjg/gradle-5.1.1/bin/gradle

# SETTINGS FOR GRADLE 5.4.1
ADD https://services.gradle.org/distributions/gradle-5.4.1-all.zip /tmp
RUN mkdir -p /opt/gradle/gradle-5.4.1/wrapper/dists/gradle-5.4.1-all/3221gyojl5jsh0helicew7rwx
RUN cp /tmp/gradle-5.4.1-all.zip /opt/gradle/gradle-5.4.1/wrapper/dists/gradle-5.4.1-all/3221gyojl5jsh0helicew7rwx/
RUN unzip /tmp/gradle-5.4.1-all.zip -d /opt/gradle/gradle-5.4.1/wrapper/dists/gradle-5.4.1-all/3221gyojl5jsh0helicew7rwx
RUN touch /opt/gradle/gradle-5.4.1/wrapper/dists/gradle-5.4.1-all/3221gyojl5jsh0helicew7rwx/gradle-5.4.1-all.ok
RUN touch /opt/gradle/gradle-5.4.1/wrapper/dists/gradle-5.4.1-all/3221gyojl5jsh0helicew7rwx/gradle-5.4.1-all.lck
#RUN /opt/gradle/gradle-5.4.1/wrapper/dists/gradle-5.4.1-all/3221gyojl5jsh0helicew7rwx/gradle-5.4.1/bin/gradle


ENV GRADLE_USER_HOME=/opt/gradle

# add ccache to PATH
ENV PATH /usr/lib/ccache:${PATH}

# use ccache for NDK builds
ENV NDK_CCACHE /usr/bin/ccache

ENV CCACHE_DIR /mnt/ccache
