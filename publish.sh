#!/bin/bash

hexo g

tar cvjf a.tar public

scp -i ~/.ssh/key0.pem a.tar root@47.91.238.107:/opt/nginx/html/

ssh -i ~/.ssh/key0.pem root@47.91.238.107 "cd /opt/nginx/html/; tar xvjf a.tar;rm -rf a.tar sixianed.com;mv public sixianed.com;"

rm a.tar

exit
