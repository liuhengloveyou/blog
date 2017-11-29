#!/bin/bash

hexo g

tar cvf a.tar public

scp -i ~/.ssh/key1 a.tar root@119.23.252.180:/opt/nginx/html/

ssh  -i ~/.ssh/key1 root@119.23.252.180 "cd /opt/nginx/html/; rm -rf public; tar xvf a.tar; rm a.tar"

rm a.tar;

exit
