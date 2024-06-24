ARG BUILD_FROM
FROM $BUILD_FROM

COPY ./run.bash ../ddns.bash /

CMD [ "/run.bash" ]
