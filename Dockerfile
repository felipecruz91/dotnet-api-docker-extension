# syntax=docker/dockerfile:1.4
FROM mcr.microsoft.com/dotnet/sdk:6.0-alpine AS builder
WORKDIR /source

# COPY vm/* .
COPY vm/**/*.csproj .
RUN for file in $(ls *.csproj); do mkdir -p ${file%.*}/ && mv $file ${file%.*}/; done
COPY vm/MySolution.sln .

RUN --mount=type=cache,id=nuget,target=/root/.nuget/packages \
    dotnet restore MySolution.sln \
    --runtime alpine-x64

COPY vm .
RUN  --mount=type=cache,id=nuget,target=/root/.nuget/packages  \
     dotnet publish -c Release -o /app \
     --no-restore \
     --packages /root/.nuget/packages \
     --runtime alpine-x64 \
     --self-contained true \
     /p:PublishTrimmed=true \
     /p:PublishSingleFile=true

FROM --platform=$BUILDPLATFORM node:18.9-alpine3.15 AS client-builder
WORKDIR /ui
# cache packages in layer
COPY ui/package.json /ui/package.json
COPY ui/package-lock.json /ui/package-lock.json
RUN --mount=type=cache,target=/usr/src/app/.npm \
    npm set cache /usr/src/app/.npm && \
    npm ci
# install
COPY ui /ui
RUN npm run build

FROM mcr.microsoft.com/dotnet/runtime-deps:6.0-alpine
LABEL org.opencontainers.image.title="My dotnet API extension" \
    org.opencontainers.image.description="My awesome Docker extension" \
    org.opencontainers.image.vendor="Felipe" \
    com.docker.desktop.extension.api.version="0.3.0" \
    com.docker.extension.screenshots="" \
    com.docker.extension.detailed-description="" \
    com.docker.extension.publisher-url="" \
    com.docker.extension.additional-urls="" \
    com.docker.extension.changelog=""

COPY --from=builder /app .
COPY docker-compose.yaml .
COPY metadata.json .
COPY docker.svg .
COPY --from=client-builder /ui/build ui
CMD ./MyAPI 
