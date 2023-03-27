# ep3-bs.nix

This flake aims to provide a nixosModule that handles running an [ep3-bs](https://bs.hbsys.de/) instance.

## What does it look like?

Here is a minimal configuration:
``` nix
{
  services.ep3-bs.enable = true;
  services.ep3-bs.mail.address = "test@test.de";
}
```

Now you can access ep3-bs using your browser. You will be guided through the database setup in the frontend. Afterwards you have to manually delete the ```setup.php```. This only has to be done once on the initial setup.

It can be done as root with:
``` shell
rm /var/lib/ep3-bs/public/setup.php
```

If there is a better solution using nix, please let me know.

## Installation

### Using flakes

Add ep3-bs as input:
``` nix
{
  # ...
  inputs.ep3-bs.url = github:kalipso/ep3-bs.nix;
}
```

