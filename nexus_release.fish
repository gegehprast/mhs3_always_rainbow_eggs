#!/usr/bin/env fish

for name in AlwaysRainbowEggs AutoStorePickedUpEggs
    set zipfile $name.zip
    if test -f $zipfile
        rm $zipfile
    end
    7z a $zipfile $name.lua
    echo "Created $zipfile"
end
