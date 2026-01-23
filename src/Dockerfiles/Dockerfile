ARG BUILDPLATFORM=linux/amd64
FROM --platform=${BUILDPLATFORM} public.ecr.aws/lambda/python:3.12 AS build

WORKDIR /app

COPY requirements.txt .

RUN pip install --target ./package -r requirements.txt

FROM busybox AS export
COPY --from=build /app/package /out