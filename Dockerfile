FROM perl:5.40-slim

# Install OS dependencies and cpanm
RUN apt-get update && apt-get install -y --no-install-recommends \
    make \
    gcc \
    libxml2-dev \
    libexpat1-dev \
    curl \
    && curl -L https://cpanmin.us | perl - App::cpanminus \
    && rm -rf /var/lib/apt/lists/*

# Install Perl dependencies
RUN cpanm --notest \
    Mojolicious \
    Geo::Gpx \
    XML::Descent \
    Date::Parse \
    HTTP::Tiny

WORKDIR /app

# Copy application files
COPY processGPX server.pl ./
COPY web/ web/

# Make processGPX executable
RUN chmod +x processGPX

EXPOSE 8080

CMD ["perl", "server.pl"]
