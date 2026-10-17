#!/usr/bin/bash

export QT_QPA_PLATFORM=xcb
exec env QT_QPA_PLATFORM=xcb copyq --clipboard-access monitorClipboard
