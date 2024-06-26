# Building Lix from Source

<div class="warning">

FIXME(meson): This section is outdated for meson and has been commented out. See https://git.lix.systems/lix-project/lix/issues/258

</div>

<!--
After cloning Lix's Git repository, issue the following commands:

```console
$ autoreconf -vfi
$ ./configure options...
$ make
$ make install
```

Nix requires GNU Make so you may need to invoke `gmake` instead.

The installation path can be specified by passing the `--prefix=prefix`
to `configure`. The default installation directory is `/usr/local`. You
can change this to any location you like. You must have write permission
to the *prefix* path.

Nix keeps its *store* (the place where packages are stored) in
`/nix/store` by default. This can be changed using
`--with-store-dir=path`.

> **Warning**
>
> It is best *not* to change the Nix store from its default, since doing
> so makes it impossible to use pre-built binaries from the standard
> Nixpkgs channels — that is, all packages will need to be built from
> source.

Nix keeps state (such as its database and log files) in `/nix/var` by
default. This can be changed using `--localstatedir=path`.
-->
