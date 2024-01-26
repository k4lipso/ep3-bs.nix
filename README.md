# ep3-bs.nix

This flake aims to provide a nixosModule that handles running an [ep3-bs](https://bs.hbsys.de/) instance.

## Usage

Here is a minimal configuration:
``` nix
{
  services.ep3-bs = {
    enable = true;
    mail.address = "test@test.de";
    database.user = "testuser3";
    database.password = "testPassword1234"; #TODO: should be set as file
    in_production = false;
  };
}
```

Now you can access ep3-bs using your browser. You will be guided through the database setup in the frontend. When you are done set ```service.ep3-bs.in_production = true``` and rebuild your machine.

If there is a better solution where you dont have to toggle the in_production variable, please let me know.

