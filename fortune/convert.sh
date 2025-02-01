#!/bin/sh

for img in /images/*
do
	magick $img -resize 800x600 $img
done
