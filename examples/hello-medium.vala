public class HelloMedium {
    public static int main (string[] args) {
        string user = "user";
        string password = "Integration token";

        try {
            Medium.Client client = new Medium.Client ();
            string access_token;
            if (client.authenticate (
                    user,
                    password,
                    out access_token))
            {
                print ("Successfully logged in\n");
            } else {
                print ("Could not login");
                return 0;
            }

            string my_username;
            if (client.get_authenticated_user (out my_username)) {
                print ("Logged in as: %s\n", my_username);
            }

            string url;
            string id;
            if (client.publish_post (
                out url,
                out id,
                "# Hello Medium!

Hello from [ThiefMD](https://thiefmd.com)!",
                "Hello Medium!"))
            {
                print ("Made post: %s\n", url);
            }
        } catch (Error e) {
            warning ("Failed: %s", e.message);
        }
        return 0;
    }
}