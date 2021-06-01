# Examples

Run virtual machine which is used in tests:
```
nix run .#vm
```

Temporarily override flake.lock:
``` shell
nix flake check --keep-failed -L --override-input majordomo git+file:///home/oleg/majordomo/_ci/nixpkgs --override-input containerImageApache git+file:///home/oleg/majordomo/webservices/apache2-php73
```
