# medium-vala

Unofficial [Medium](https://medium.com) API client library for Vala. Still a work in progress.

## Compilation

I recommend including `medium-vala` as a git submodule and adding `medium-vala/src/Medium.vala` to your sources list. This will avoid packaging conflicts and remote build system issues until I learn a better way to suggest this.

### Requirements

```
meson
ninja-build
valac
libgtk-3-dev
```

### Building

```bash
meson build
cd build
meson configure -Denable_examples=true
ninja
./examples/hello-medium
```

Examples require update to username and password, don't check this in

```
string user = "username";
string password = "password";
```

# Quick Start


## New Login

```vala
string user = "user";
string key = "integration-key";

Medium.Client client = new Medium.Client ();
if (client.authenticate (
        user,
        key))
{
    print ("Successfully logged in");
} else {
    print ("Could not login");
}
```

## Check Logged in User

```vala
string my_username;
if (client.get_authenticated_user (out my_username)) {
    print ("Logged in as: %s", my_username);
}
```

## Publish a Post

```vala
string url;
string id;
if (client.publish_post (
    out url,
    out id,
    "# Hello Medium!

Hello from [ThiefMD](https://thiefmd.com)!",
    "Hello Medium!"))
{
    print ("Made post: %s", url);
}
```

## Upload an Image

```vala
string file_url = "";
if (client.upload_image_simple (
    out file_url,
    "/home/user/Pictures/photo.png"
))
{
    print ("Uploaded: %s", file_url);
}
```
