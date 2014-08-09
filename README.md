![Houston](https://raw.github.com/mattt/nomad-cli.com/assets/houston-banner.png)

Push Notifications don't have to be difficult.

Houston is a simple gem for sending Apple Push Notifications. Pass your credentials, construct your message, and send it.

In a production application, you will probably want to schedule or queue notifications into a background job. Whether you're using [queue_classic](https://github.com/ryandotsmith/queue_classic), [resque](https://github.com/defunkt/resque), or rolling you own infrastructure, integrating Houston couldn't be simpler.

Another caveat is that Houston doesn't manage device tokens for you. For that, you should check out [Helios](http://helios.io)

> Houston is named for [Houston, TX](http://en.wikipedia.org/wiki/Houston), the metonymical home of [NASA's Johnson Space Center](http://en.wikipedia.org/wiki/Lyndon_B._Johnson_Space_Center), as in _Houston, We Have Liftoff!_.

> It's part of a series of world-class command-line utilities for iOS development, which includes [Cupertino](https://github.com/mattt/cupertino) (Apple Dev Center management), [Shenzhen](https://github.com/mattt/shenzhen) (Building & Distribution), [Venice](https://github.com/mattt/venice) (In-App Purchase Receipt Verification), and [Dubai](https://github.com/mattt/dubai) (Passbook pass generation).

> This project is also part of a series of open source libraries covering the mission-critical aspects of an iOS app's infrastructure. Be sure to check out its sister projects: [GroundControl](https://github.com/mattt/GroundControl), [SkyLab](https://github.com/mattt/SkyLab), [houston](https://github.com/mattt/houston), and [Orbiter](https://github.com/mattt/Orbiter).

## Installation

    $ gem install houston

## Usage

```ruby
require 'houston'

# Environment variables are automatically read, or can be overridden by any specified options. You can also
# conveniently use `Houston::Client.development` or `Houston::Client.production`.
APN = Houston::Client.development
APN.certificate = File.read("/path/to/apple_push_notification.pem")

# An example of the token sent back when a device registers for notifications
token = "<ce8be627 2e43e855 16033e24 b4c28922 0eeda487 9c477160 b2545e95 b68b5969>"

# Create a notification that alerts a message to the user, plays a sound, and sets the badge on the app
notification = Houston::Notification.new(device: token)
notification.alert = "Hello, World!"

# Notifications can also change the badge count, have a custom sound, have a category identifier, indicate available Newsstand content, or pass along arbitrary data.
notification.badge = 57
notification.sound = "sosumi.aiff"
notification.category = "INVITE_CATEGORY"
notification.content_available = true
notification.custom_data = {foo: "bar"}

# And... sent! That's all it takes.
APN.push(notification)
```

### Error Handling

If an error occurs when sending a particular notification, its `error` attribute will be populated:

```ruby
puts "Error: #{notification.error}." if notification.error
```

### Silent Notifications

To send a silent push notification, set `sound` to an empty string (`''`):

```ruby
Houston::Notification.new(:sound => '',
                          :content_available => true)
```

### Persistent Connections

If you want to manage your own persistent connection to Apple push services, such as for background workers, here's how to do it:

```ruby
certificate = File.read("/path/to/apple_push_notification.pem")
passphrase = "..."
connection = Houston::Connection.new(Houston::APPLE_DEVELOPMENT_GATEWAY_URI, certificate, passphrase)
connection.open

notification = Houston::Notification.new(device: token)
notification.alert = "Hello, World!"
connection.write(notification.message)

connection.close
```

### Feedback Service

Apple provides a feedback service to query for unregistered device tokens, these are devices that have failed to receive a push notification and should be removed from your application. You should periodically query for and remove these devices, Apple audits providers to ensure they are removing unregistered devices. To obtain the list of unregistered device tokens:

```ruby
Houston::Client.development.devices
```

## Versioning

Houston 2.0 supports the new [enhanced notification format](https://developer.apple.com/library/ios/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/Chapters/CommunicatingWIthAPS.html#//apple_ref/doc/uid/TP40008194-CH101-SW4). Support for the legacy notification format is available in 1.x releases.

## Command Line Tool

Houston also comes with the `apn` binary, which provides a convenient way to test notifications from the command line.

    $ apn push "<token>" -c /path/to/apple_push_notification.pem -m "Hello from the command line!"

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

    $ openssl pkcs12 -in cert.p12 -out apple_push_notification.pem -nodes -clcerts

## Contact

Mattt Thompson

- http://github.com/mattt
- http://twitter.com/mattt
- m@mattt.me

## License

Houston is available under the MIT license. See the LICENSE file for more info.
