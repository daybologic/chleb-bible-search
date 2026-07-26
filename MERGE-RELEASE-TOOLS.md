Need a bunch of tools in bin/
to help with merging in branches, tagging releases and so on,
to automate some of the pain away. Including bumping version numbers.

It needs to do something like:
```
find lib -name "*.pl" -type f
```

and then examine the $VERSION with awk, and change the version number to that which is in the top of debian/changelog (on the first line).
The first line of debian/changelog is authoritative for the version number.

The non-authoritative version also appears in swagger.yaml and will need to be bumped there too.
Additionally, README.md contains references to the version number which will need to be changed.

Read back the entire git history of the project to determine what I do when I realease the code.
