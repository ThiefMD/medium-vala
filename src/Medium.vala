namespace Medium {
    public const string LOGOUT = "auth/me";
    public const string USER = "me";
    public const string USER_CHANNELS = "users/%s/publications";
    public const string IMAGE_UPLOAD = "images";

    public class Client {
        public string endpoint = "https://api.medium.com/v1/";
        private string? authenticated_user;
        private string? authenticated_user_id;
        private string? authenticated_user_url;

        public Client (string url = "") {
            if (url.chomp ().chug () != "") {
                string uri = url.chomp ().chug ();
                if (!uri.has_suffix ("/")) {
                    uri += "/";
                }
                endpoint = uri;
            }

            if (!endpoint.has_prefix ("http")) {
                endpoint = "https://" + endpoint;
            }

            authenticated_user = null;
        }

        public bool set_token (string auth_token) {
            authenticated_user = auth_token;
            string user;
            if (!get_authenticated_user (out user)) {
                authenticated_user = null;
                return false;
            }

            return true;
        }

        public bool upload_image_simple (
            out string file_url,
            string local_file_path,
            string user_token = ""
        )
        {
            file_url = "";

            string auth_token = "";
            bool result = false;
            if (user_token == "" && authenticated_user != null) {
                auth_token = authenticated_user;
            } else {
                auth_token = user_token;
            }

            if (auth_token == "") {
                warning ("Image upload requires authentication token");
                return false;
            }

            File upload_file = File.new_for_path (local_file_path);
            string file_mimetype = "application/octet-stream";

            if (!upload_file.query_exists ()) {
                warning ("Invalid file provided");
                return false;
            }

            uint8[] file_data;
            try {
                GLib.FileUtils.get_data(local_file_path, out file_data);
            } catch (GLib.FileError e) {
                warning(e.message);
                return false;
            }

            bool uncertain = false;
            string? st = ContentType.guess (upload_file.get_basename (), file_data, out uncertain);
            if (!uncertain || st != null) {
                file_mimetype = ContentType.get_mime_type (st);
            }

            debug ("Will upload %s : %s", file_mimetype, local_file_path);

            Soup.Buffer buffer = new Soup.Buffer.take(file_data);
            Soup.Multipart multipart = new Soup.Multipart("multipart/form-data");
            multipart.append_form_file ("file", upload_file.get_path (), file_mimetype, buffer);
            // multipart.append_form_string ("ref", Soup.URI.encode(upload_file.get_basename ()), file_mimetype, buffer);

            WebCall call = new WebCall (endpoint, IMAGE_UPLOAD);
            call.set_multipart (multipart);
            call.add_header ("Authorization", "%s".printf (auth_token));
            call.perform_call ();

            if (call.response_code >= 200 && call.response_code < 300) {
                result = true;
            } else {
                return false;
            }

            try {
                var parser = new Json.Parser ();
                parser.load_from_data (call.response_str);
                Json.Node data = parser.get_root ();
                ImageResponse response = Json.gobject_deserialize (
                    typeof (ImageResponse),
                    data)
                    as ImageResponse;

                if (response != null) {
                    result = true;
                    file_url = response.data.url;
                }
            } catch (Error e) {
                warning ("Error parsing response: %s", e.message);
                warning (call.response_str);
            }

            return result;
        }

        public bool update_post (
            string post_id,
            string token,
            string body,
            string title,
            string font = "serif",
            string lang = "en",
            bool rtl = false,
            string user_token = "")
        {
            bool post_updated = false;
            string auth_token = "";
            if (user_token == "" && authenticated_user != null) {
                auth_token = authenticated_user;
            } else {
                auth_token = user_token;
            }

            if (token == "" && auth_token == "") {
                warning ("No valid way to authenticate to update post");
                return false;
            }

            PostUpdateRequestData post_update = new PostUpdateRequestData ();
            post_update.token = token;
            post_update.body = body;
            post_update.title = title;
            post_update.font = font;
            post_update.lang = lang;
            post_update.rtl = rtl;

            Json.Node root = Json.gobject_serialize (post_update);
            Json.Generator generate = new Json.Generator ();
            generate.set_root (root);
            generate.set_pretty (false);
            string request_body = generate.to_data (null);

            WebCall make_post = new WebCall (endpoint, "posts/" + post_id);
            make_post.set_get ();
            make_post.set_body (request_body);
            if (auth_token != "") {
                make_post.add_header ("Authorization", "Bearer %s".printf (auth_token));
            }

            if (!make_post.perform_call ()) {
                return false;
            }

            try {
                Json.Parser parser = new Json.Parser ();
                parser.load_from_data (make_post.response_str);
                Json.Node data = parser.get_root ();
                PostResponse response = Json.gobject_deserialize (
                    typeof (PostResponse),
                    data)
                    as PostResponse;

                if (response != null) {
                    post_updated = true;
                }
            } catch (Error e) {
                warning ("Unable to validate token: %s", e.message);
            }

            return post_updated;
        }

        public bool get_post (out Post post, string post_id)
        {
            bool post_obtained = false;
            post = null;
            if (post_id == "") {
                return false;
            }

            WebCall get_existing_post = new WebCall (endpoint, "posts/" + post_id);
            get_existing_post.set_get ();
            if (!get_existing_post.perform_call ()) {
                return false;
            }

            try {
                Json.Parser parser = new Json.Parser ();
                parser.load_from_data (get_existing_post.response_str);
                Json.Node data = parser.get_root ();
                PostResponse response = Json.gobject_deserialize (
                    typeof (PostResponse),
                    data)
                    as PostResponse;

                if (response != null) {
                    post_obtained = true;
                    post = response.data;
                }
            } catch (Error e) {
                warning ("Unable to validate token: %s", e.message);
            }

            return post_obtained;
        }

        public bool publish_post (
            out string url,
            out string id,
            string content,
            string title,
            string publishStatus = "draft",
            string format = "markdown",
            bool notifyFollowers = false,
            string[]? tags = null,
            string publicationId = "",
            string canonicalUrl = "",
            string license = "",
            string user_token = "")
        {
            string auth_token = "";
            url = "";
            id = "";
            bool published_post = false;
            if (user_token == "" && authenticated_user != null) {
                auth_token = authenticated_user;
            } else {
                auth_token = user_token;
            }

            PostRequestData new_post = new PostRequestData ();
            new_post.content = content;
            new_post.title = title;
            new_post.contentFormat = format;
            new_post.publishStatus = publishStatus;
            if (license != "") {
                new_post.license = license;
            }
            if (canonicalUrl != "") {
                new_post.canonicalUrl = canonicalUrl;
            }
            new_post.notifyFollowers = notifyFollowers;
            if (tags != null && tags.length != 0) {
                new_post.tags = tags;
            }

            Json.Node root = Json.gobject_serialize (new_post);
            Json.Generator generate = new Json.Generator ();
            generate.set_root (root);
            generate.set_pretty (false);
            string request_body = generate.to_data (null);

            string api_path = "users/%s/posts".printf (authenticated_user_id);
            WebCall make_post = new WebCall (endpoint, api_path);
            make_post.set_post ();
            make_post.set_body (request_body);
            if (auth_token != "") {
                make_post.add_header ("Authorization", "Bearer %s".printf (auth_token));
            }

            if (!make_post.perform_call ()) {
                warning ("Error: %u, %s", make_post.response_code, make_post.response_str);
                return false;
            }

            try {
                Json.Parser parser = new Json.Parser ();
                parser.load_from_data (make_post.response_str);
                Json.Node data = parser.get_root ();
                PostResponse response = Json.gobject_deserialize (
                    typeof (PostResponse),
                    data)
                    as PostResponse;

                if (response != null) {
                    published_post = true;
                    url = response.data.url;
                    id = response.data.id;
                }
            } catch (Error e) {
                warning ("Unable to publish post: %s", e.message);
            }

            return published_post;
        }

        public bool get_user_collections (ref GLib.List<Collection> collections, string user_token = "") {
            string auth_token = "";
            bool got_collections = false;
            if (user_token == "" && authenticated_user != null) {
                auth_token = authenticated_user;
            } else {
                auth_token = user_token;
            }

            if (auth_token == "") {
                return false;
            }

            WebCall collection_call = new WebCall (endpoint, "me/collections");
            collection_call.set_get ();
            collection_call.add_header ("Authorization", "Bearer %s".printf (auth_token));

            bool res = collection_call.perform_call ();
            debug ("Got bytes: %d", res ? collection_call.response_str.length : 0);

            if (!res) {
                return false;
            }

            try {
                Json.Parser parser = new Json.Parser ();
                parser.load_from_data (collection_call.response_str);
                Json.Node data = parser.get_root ();
                var json_obj = parser.get_root ().get_object ();
                UserCollections response = Json.gobject_deserialize (
                    typeof (UserCollections),
                    data)
                    as UserCollections;

                if (response != null) {
                    var collection_data = json_obj.get_array_member ("data");
                    foreach (var co in collection_data.get_elements ()) {
                        var c_p = co.get_object ();
                        Collection c = new Collection ();
                        deserialize_collection (ref c, c_p);
                        collections.append (c);
                    }
                    got_collections = true;
                }
            } catch (Error e) {
                warning ("Unable to get user collections: %s", e.message);
            }

            return got_collections;
        }

        private void deserialize_collection (ref Collection c, Json.Object c_p) {
            c.alias = c_p.has_member ("alias") ? c_p.get_string_member ("alias") : "";
            c.title = c_p.has_member ("title") ? c_p.get_string_member ("title") : "";
            c.description  = c_p.has_member ("description") ? c_p.get_string_member ("description") : "";
            c.style_sheet = c_p.has_member ("style_sheet") ? c_p.get_string_member ("style_sheet") : "";
            c.public = c_p.has_member ("public") ? c_p.get_boolean_member ("public") : false;
            c.views = (int) (c_p.has_member ("views") ? c_p.get_int_member ("views") : 0);
            c.email = c_p.has_member ("email") ? c_p.get_string_member ("email") : "";
            c.url = c_p.has_member ("url") ? c_p.get_string_member ("url") : "";
            c.monetization_pointer = c_p.has_member ("monetization_pointer") ? c_p.get_string_member ("monetization_pointer") : "";
        }

        public bool get_authenticated_user (out string username, string user_token = "") {
            username = "";
            bool logged_in = false;
            string auth_token = "";
            if (user_token == "" && authenticated_user != null) {
                auth_token = authenticated_user;
            } else {
                auth_token = user_token;
            }

            if (auth_token == "") {
                return false;
            }

            WebCall authentication = new WebCall (endpoint, USER);
            authentication.set_get ();
            authentication.add_header ("Authorization", "Bearer %s".printf (auth_token));

            bool res = authentication.perform_call ();
            debug ("Got bytes: %d", res ? authentication.response_str.length : 0);

            if (!res) {
                return false;
            }

            try {
                Json.Parser parser = new Json.Parser ();
                parser.load_from_data (authentication.response_str);
                Json.Node data = parser.get_root ();
                MeResponse response = Json.gobject_deserialize (
                    typeof (MeResponse),
                    data)
                    as MeResponse;

                if (response != null) {
                    logged_in = true;
                    username = response.data.username;
                    authenticated_user = auth_token;
                    authenticated_user_id = response.data.id;
                    authenticated_user_url = response.data.url;
                }
            } catch (Error e) {
                warning ("Unable to validate token: %s", e.message);
            }

            return logged_in;
        }

        public bool authenticate (
            string alias,
            string password,
            out string access_token) throws GLib.Error
        {
            string user = "";
            access_token = "";

            bool logged_in = get_authenticated_user (out user, password);

            if (logged_in) {
                access_token = password;
                authenticated_user = password;
            }

            return logged_in;
        }
    }

    public class Response : GLib.Object, Json.Serializable {
    }

    public class PostResponse : Response {
        public Post data { get; set; }
    }

    public class ImageResponse : Response {
        public Image data { get; set; }
    }

    public class MarkdownData : GLib.Object, Json.Serializable {
        public string body { get; set; }
    }

    public class UserPosts : Response {
    }

    public class UserCollections : Response {
    }

    public class Image : GLib.Object, Json.Serializable {
        public string url { get; set; }
        public string md5 { get; set; }
    }

    public class Post : GLib.Object, Json.Serializable {
        public string id { get; set; }
        public string title { get; set; }
        public string authorId { get; set; }
        public string[] tags { get; set; }
        public string url { get; set; }
        public string canonicalUrl { get; set; }
        public string publishStatus { get; set; }
        public string publishedAt { get; set; }
        public string license { get; set; }
        public bool licenseUrl { get; set; }
    }

    public class Collection : GLib.Object, Json.Serializable {
        public string alias { get; set; }
        public string title { get; set; }
        public string description { get; set; }
        public string style_sheet  { get; set; }
        public bool @public { get; set; }
        public int views { get; set; }
        public string email { get; set; }
        public string url { get; set; }
        public string monetization_pointer { get; set; }
    }

    public class MeResponse : Response {
        public MeData data { get; set; }
    }

    public class MeData : GLib.Object, Json.Serializable {
        public string id { get; set; }
        public string username { get; set; }
        public string name { get; set; }
        public string url { get; set; }
        public string imageUrl { get; set; }
    }

    private class Login : GLib.Object, Json.Serializable {
        public string alias { get; set; }
        public string pass { get; set; }
    }

    public class LoginResponse : Response {
        public LoginData data { get; set; }
    }

    private class PostClaimData : GLib.Object, Json.Serializable {
        public string token { get; set; }
        public string id { get; set; }
    }

    private class PostDeleteData : GLib.Object, Json.Serializable {
        public string token { get; set; }
    }

    private class PostRequestData : GLib.Object, Json.Serializable {
        public string title { get; set; }
        public string contentFormat { get; set; }
        public string content { get; set; }
        public string[] tags { get; set; }
        public string? canonicalUrl { get; set; }
        public string publishStatus { get; set; }
        public string? license { get; set; }
        public bool notifyFollowers { get; set; }
    }

    private class PostUpdateRequestData : GLib.Object, Json.Serializable {
        public string token { get; set; }
        public string body { get; set; }
        public string title { get; set; }
        public string font { get; set; }
        public string lang { get; set; }
        public bool rtl { get; set; }
    }

    private class MarkdownRequestData : GLib.Object, Json.Serializable {
        public string raw_body { get; set; }
    }

    public class LoginData : GLib.Object, Json.Serializable {
        public string access_token { get; set; }
        public UserData user { get; set; }
    }

    public class UserData : GLib.Object, Json.Serializable {
        public string username { get; set; }
        public string email { get; set; }
        public string created { get; set; }
    }

    private class WebCall {
        private Soup.Session session;
        private Soup.Message message;
        private string url;
        private string body;
        private bool is_mime = false;

        public string response_str;
        public uint response_code;

        public class WebCall (string endpoint, string api) {
            url = endpoint + api;
            session = new Soup.Session ();
            body = "";
        }

        public void set_body (string data) {
            body = data;
        }

        public void set_multipart (Soup.Multipart multipart) {
            message = Soup.Form.request_new_from_multipart (url, multipart);
            add_header ("Content-Type", Soup.FORM_MIME_TYPE_MULTIPART);
            is_mime = true;
        }

        public void set_get () {
            message = new Soup.Message ("GET", url);
        }

        public void set_delete () {
            message = new Soup.Message ("DELETE", url);
        }

        public void set_post () {
            message = new Soup.Message ("POST", url);
        }

        public void add_header (string key, string value) {
            message.request_headers.append (key, value);
        }

        public bool perform_call () {
            MainLoop loop = new MainLoop ();
            bool success = false;
            debug ("Calling %s", url);

            if (body != "") {
                message.set_request ("application/json", Soup.MemoryUse.COPY, body.data);
            } else {
                if (!is_mime) {
                    add_header ("Content-Type", "application/json");
                }
            }

            session.queue_message (message, (sess, mess) => {
                response_str = (string) mess.response_body.flatten ().data;
                response_code = mess.status_code;

                if (response_str != null && response_str != "") {
                    success = true;
                    debug ("Non-empty body");
                }

                if (response_code >= 200 && response_code <= 250) {
                    success = true;
                    debug ("Success HTTP code");
                }
                loop.quit ();
            });

            loop.run ();
            return success;
        }
    }
}
