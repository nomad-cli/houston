# Houston
**Apple Push Notifications. No Dirigible Required**

> Houston, We Have Liftoff!

Push Notifications don't have to be difficult.

Houston is a simple gem for sending Apple Push Notifications. Pass your credentials, construct your message, and send it.

In a production application, you will probably want to schedule or queue notifications into a background job. Whether you're using [queue_classic](https://github.com/ryandotsmith/queue_classic), [resque](https://github.com/defunkt/resque), or rolling you own infrastructure, integrating Houston couldn't be simpler.

Another caveat is that Houston doesn't manage device tokens for you. Infrastructures can vary dramatically for these kinds of things, so being agnostic and not forcing any conventions here is more a feature than a bug, perhaps. Treat it the same way as you would an e-mail address, associating one or many for each user account.

_That said, a simple web service adapter, similar to [Rack::CoreData](https://github.com/mattt/rack-core-data) is in the cards._

## Installation

```
$ gem install houston
```

## Usage

```ruby
# Environment variables are automatically read, or can be overridden by any specified options 
APN = Houston::Client.new
APN.certificate = File.read("/path/to/apple_push_notification.pem")

# An example of the token sent back when a device registers for notifications
token = "<ce8be627 2e43e855 16033e24 b4c28922 0eeda487 9c477160 b2545e95 b68b5969>"

# Create a notification that alerts a message to the user, plays a sound, and sets the badge on the app
notification = Houston::Notification.new(device: token)
notification.alert = "Hello, World!"

# Notifications can also change the badge count, have a custom sound, or pass along arbitrary data.
notification.badge = 57
notification.sound = "sosumi.aiff"
notification.custom_data = {foo: "bar"}

# And... sent! That's all it takes.
APN.push(notification)
```

## Command Line Tool

Houston also comes with the `apn` binary, which provides a convenient way to test notifications from the command line.

```
$ apn push "<token>" -c /path/to/apple_push_notification.pem -m "Hello from the command line!"
```

## Enabling Push Notifications on iOS

### AppDelegate.m

```objective-c
- (void)applicationDidFinishLaunching:(UIApplication *)application {
  // ...

  [[UIApplication sharedApplication] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound)];
}

- (void)application:(UIApplication *)application 
didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken 
{
    NSLog(@"application:didRegisterForRemoteNotificationsWithDeviceToken: %@", deviceToken);

    // Register the device token with a webservice
}

- (void)application:(UIApplication *)application
didFailToRegisterForRemoteNotificationsWithError:(NSError *)error 
{
    NSLog(@"Error: %@", error);
}
```

## Converting Your Certificate

> These instructions come from the [APN on Rails](https://github.com/PRX/apn_on_rails) project, which is another great option for sending push notifications.

Once you have the certificate from Apple for your application, export your key
and the apple certificate as p12 files. Here is a quick walkthrough on how to do this:

1. Click the disclosure arrow next to your certificate in Keychain Access and select the certificate and the key. 
2. Right click and choose `Export 2 items…`. 
3. Choose the p12 format from the drop down and name it `cert.p12`.

Now covert the p12 file to a pem file:

```
$ openssl pkcs12 -in cert.p12 -out apple_push_notification.pem -nodes -clcerts
```

## Contact

Mattt Thompson

- http://github.com/mattt
- http://twitter.com/mattt
- m@mattt.me

## License

Houston is available under the MIT license. See the LICENSE file for more info.
