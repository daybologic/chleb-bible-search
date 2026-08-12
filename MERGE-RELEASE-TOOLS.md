Need some new tools in bin/
to help with merging in branches, tagging releases and so on,
to automate some of the pain away. Including bumping version numbers.

We need to call these tools:
 * bumpversion
 * rcbranch
 * release

'bumpversion' needs to do something like:
```
find lib -name "*.pl" -type f
```

and then examine the $VERSION with awk, and change the version number to that which is in the top of debian/changelog (on the first line).
The first line of debian/changelog is authoritative for the version number.

The non-authoritative version also appears in swagger.yaml and will need to be bumped there too.
Additionally, README.md contains references to the version number which will need to be changed.

'rcbranch' needs to make a new release branch in the form 'rel/X.Y' (X is major, Y is minor).
Unless we are releasing a patch, in which case, the previous rel/ branch should have contents of master merged into it.
Ask the user what the purpose of the release is, ie. major release, minor release, or patch.

'release' needs to do some sanity checks
 # t/version.t needs to pass
 # make a Debian deb file using sbuild

Read back the entire git history of the project to determine what I do when I realease the code.
