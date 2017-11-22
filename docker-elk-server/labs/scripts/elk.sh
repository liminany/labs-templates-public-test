#!/bin/sh   
cd /home/leansoft                                                                        
git clone https://github.com/lean-soft/elk.git                                      
cd /home/leansoft/elk                                                               
docker-compose -f docker-elk-only.yml up -d