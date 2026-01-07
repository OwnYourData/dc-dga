FROM oydeu/dc-base
LABEL org.opencontainers.image.authors="Christoph Fabianek <christoph@ownyourdata.eu>"

RUN apt-get update && \
	apt-get install -y --no-install-recommends \
		libjpeg62-turbo \
		libxext6 \
		libxrender1 \
		libfontconfig1 \
		libfreetype6 \
		libpng16-16 \
		libx11-6 \
		xfonts-75dpi \
		xfonts-base \
		chromium \
		fonts-liberation \
		libappindicator3-1 \
		xdg-utils \
		shared-mime-info && \
	rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
	apt-get clean

COPY Gemfile.extend $RAILS_ROOT
RUN git config --global url."https://".insteadOf git:// && \
	bundle install && \
	bundle update

ENV BROWSER_PATH=/usr/bin/chromium

COPY . .
RUN mv public/index.html public/databud.html

CMD ["./script/init_dao.sh"]

EXPOSE 3000
