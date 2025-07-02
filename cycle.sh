#!/bin/sh

lua -l utils -e 't={1,2,3, y = 2};t[30] = -1;t[4]=t;t.x=t;print(t)'
