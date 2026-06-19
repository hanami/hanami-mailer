<!--- This file is synced from hanakai-rb/repo-sync -->

[actions]: https://github.com/hanami/hanami-mailer/actions
[chat]: https://discord.gg/naQApPAsZB
[forum]: https://discourse.hanamirb.org
[rubygem]: https://rubygems.org/gems/hanami-mailer

# hanami-mailer [![Gem Version](https://badge.fury.io/rb/hanami-mailer.svg)][rubygem] [![CI Status](https://github.com/hanami/hanami-mailer/workflows/CI/badge.svg)][actions]

[![Forum](https://img.shields.io/badge/Forum-dc360f?logo=discourse&logoColor=white)][forum]
[![Chat](https://img.shields.io/badge/Chat-717cf8?logo=discord&logoColor=white)][chat]

Email delivery for Hanami apps and Ruby projects.

## Installation

Add the following to your app's Gemfile.

```ruby
gem "hanami-mailer"
gem "hanami-view" # For standard mailer view rendering
```

## Usage

Mailers can be used standalone in any Ruby project, or integrated into a Hanami app. The details below focus on standalone use; for mailers in a Hanami app, see the [Hanami mailers guide](https://hanakai.org/learn/hanami/mailers).

### Basic mailer

The simplest mailer uses static headers.

```ruby
class WelcomeMailer < Hanami::Mailer
  config.paths = ["app/templates/mailers"]

  from "noreply@example.com"
  to "user@example.com"
  subject "Welcome to our app!"
end

mailer = WelcomeMailer.new
mailer.deliver
```

The HTML and text bodies come from these templates.

`app/templates/mailers/welcome_mailer.html.erb`:

```erb
<h1>Welcome to our app!</h1>
```

`app/templates/mailers/welcome_mailer.text.erb`:

```erb
Welcome to our app!
```

By default, a mailer's template is inferred from its mailer class name, e.g. `WelcomeMailer` renders
a `welcome_mailer` template. Set `config.template` to configure a name explicitly, e.g.
`config.template = "welcome"` would look for `welcome.html.erb` and `welcome.text.erb`.

### Rendering with Hanami View

Mailers render their HTML and text bodies using [Hanami View]. This is an optional dependency; add `hanami-view` to your bundle to enable it.

[Hanami View]: https://github.com/hanami/hanami-view

Hanami View settings are available directly on your mailer class, just like `config.paths` and `config.template` as used above. Each mailer builds its own view class behind the scenes to render your templates.

A mailer has two body formats, `:html` and `:text`, each rendered from its own template. The format is the first extension in the template file name: `welcome_mailer.html.erb` provides the `:html` body and `welcome_mailer.text.erb` the `:text` body.

Both HTML and text formats are rendered by default, producing a multipart email. Pass `format: :html` or `format: :text` to `#deliver` or `#prepare` to render a single format only.

Without Hanami View, mailers still send mail — you just supply the bodies yourself (see [Custom rendering without Hanami View](#custom-rendering-without-hanami-view)).

### Dynamic headers and exposures

Use header methods with blocks to compute headers dynamically based on input data.

Use `expose` to prepare values and make them available to your headers, attachments, and delivery options, and when Hanami View is available, your view templates for rendering.

```ruby
class UserMailer < Hanami::Mailer
  config.paths = ["app/templates/mailers"]

  from "notifications@example.com"
  to { |user:| user[:email] }
  subject { |user:| "Hello, #{user[:name]}!" }

  expose :user
end

mailer = UserMailer.new
mailer.deliver(user: {name: "Alice", email: "alice@example.com"})
```

The HTML and text bodies come from these templates.

`app/templates/mailers/user_mailer.html.erb`:

```erb
<h1>Hello, <%= user[:name] %>!</h1>
```

`app/templates/mailers/user_mailer.text.erb`:

```erb
Hello, <%= user[:name] %>!
```

`expose` comes in a few forms:

```ruby
# A value passed straight through from the input.
expose :user

# A value computed by a block.
expose(:greeting) { |customer:| "Hello, #{customer[:name]}!" }

# A default for optional input.
expose :greeting, default: "Hello"

# A private value: available to other exposures, headers, attachments, and delivery options, but
# never passed to the view for rendering.
private_expose :full_name do |first_name:, last_name:|
  "#{first_name} #{last_name}"
end
```

### Accessing input and exposures in blocks

Mailer class methods receiving blocks (`expose`, as well as the header methods, `attachment`, and `delivery_option`) follow one rule for their parameters:

- **Keyword parameters** receive matching keys from the `deliver` input. Give them defaults to make those keys optional.
- **Positional parameters** receive exposure values, matched by name.

```ruby
class OrderMailer < Hanami::Mailer
  from "orders@example.com"

  # `customer:` comes from the same keyword arg given to `#deliver`
  to { |customer:| customer[:email] }

  # `customer:` comes from the input; `greeting` becomes an exposure
  expose :greeting do |customer:|
    "Hello, #{customer[:name]}!"
  end

  # `greeting` receives the value from the `:greeting` exposure above
  subject { |greeting| greeting }
end

OrderMailer.new.deliver(customer: {name: "Alice", email: "alice@example.com"})
```

### Standard and custom email headers

Aside from the standard headers (which have their own dedicated convenience methods), you can add additional custom headers using `header`.

```ruby
class CampaignMailer < Hanami::Mailer
  # Standard headers, with dedicated class methods
  from "sender@example.com"
  to { |recipient:| recipient[:email] }
  cc { |cc_list:| cc_list }
  bcc "archive@example.com"
  reply_to "support@example.com"
  return_path "bounces@example.com"
  subject { |subject_line:| subject_line }

  # Custom headers for bulk emails
  header :precedence, "bulk"
  header(:list_unsubscribe) { |unsubscribe_url:| "<#{unsubscribe_url}>" }

  # Custom headers for tracking (symbol names auto-convert to Title-Case)
  header(:x_campaign_id) { |campaign:| campaign[:id] }   # => "X-Campaign-Id"
  header(:x_user_segment) { |user:| user[:segment] }     # => "X-User-Segment"

  # Use strings for exact casing control
  header "X-Mailer-Version", "2.0"
end
```

### Overriding headers at delivery time

Override any header when calling `deliver`.

```ruby
class NotificationMailer < Hanami::Mailer
  from "notifications@example.com"
  to "default@example.com"
  subject "Default Subject"
end

mailer = NotificationMailer.new
mailer.deliver(
  headers: {
    to: "priority-user@example.com",
    subject: "URGENT: Important Update",
    cc: "manager@example.com",
    x_priority: "1"
  }
)
```

### Static attachments

Load attachment files from configured paths.

```ruby
class WelcomePackMailer < Hanami::Mailer
  from "welcome@example.com"
  to { |user:| user[:email] }
  subject "Welcome Pack"

  # Configure paths to search for attachment files
  config.attachment_paths = ["public/attachments"]

  # These files will be loaded from the configured paths
  attachment "terms.pdf"
  attachment "getting-started-guide.pdf"
  attachment "company-logo.png"
end
```

You can configure multiple attachment paths in a base mailer class.

```ruby
class ApplicationMailer < Hanami::Mailer
  config.attachment_paths = [
    "app/attachments",
    "app/assets/pdfs"
  ]
end
```

If a file cannot be found in any of the configured paths, a `MissingAttachmentError` is raised.

### Dynamic attachments

Return one or more attachments from an `attachment` block, whose parameters work [like every other block](#accessing-input-and-exposures-in-blocks). Use the `file` helper to create attachment objects.

```ruby
class ReportMailer < Hanami::Mailer
  from "reports@example.com"
  to { |user:| user[:email] }
  subject "Monthly Report"

  expose :user

  # A single attachment from a block
  attachment do |user:|
    file(
      "report-#{user[:id]}.pdf",
      generate_report_pdf(user),
      content_type: "application/pdf"
    )
  end

  # You can have multiple attachment blocks
  attachment do
    file("summary.txt", "Here is your summary.")
  end

  private

  def generate_report_pdf(user)
    # ... generate PDF content
  end
end
```

You can also return multiple attachments from a single block.

```ruby
attachment do |documents:|
  documents.map do |doc|
    file(doc[:name], doc[:content])
  end
end
```

Or use a named instance method instead of a block.

```ruby
class InvoiceMailer < Hanami::Mailer
  from "billing@example.com"
  to { |customer:| customer[:email] }
  subject "Invoice"

  expose :invoice

  attachment :invoice_pdf

  private

  def invoice_pdf(invoice:)
    file(
      "invoice-#{invoice[:number]}.pdf",
      generate_pdf(invoice),
      content_type: "application/pdf"
    )
  end
end
```

### Inline attachments

Use inline attachments to embed images in your email HTML. The Content-ID is based on the filename, so you can reference it using `cid:filename`.

```ruby
class NewsletterMailer < Hanami::Mailer
  from "news@example.com"
  to { |subscriber:| subscriber[:email] }
  subject "Weekly Newsletter"

  expose :subscriber

  attachment do
    file("header-image.png", header_image_data, inline: true)
  end

  private

  def header_image_data
    File.read("app/assets/images/newsletter-header.png")
  end
end
```

In your HTML template, reference inline attachments using `cid:`.

```html
<img src="cid:header-image.png" alt="Newsletter Header">
```

Static attachments can also be made inline.

```ruby
attachment "logo.png", inline: true
```

### Runtime attachments

Add attachments at delivery time without defining them at the class level. This is useful for one-off or conditional attachments, or pre-generated files passed from calling code.

```ruby
class OrderMailer < Hanami::Mailer
  from "orders@example.com"
  to { |customer:| customer[:email] }
  subject "Order Confirmation"

  # Class-level attachment always included
  attachment "terms.pdf"
end

mailer = OrderMailer.new

# Add runtime attachments using hashes
mailer.deliver(
  customer: {email: "customer@example.com"},
  attachments: [
    {filename: "invoice-123.pdf", content: pdf_bytes},
    {filename: "receipt.txt", content: "Thank you!"}
  ]
)
# All three attachments are included: terms.pdf, invoice-123.pdf, and receipt.txt

# You can also use the Hanami::Mailer.file helper
mailer.deliver(
  customer: {email: "customer@example.com"},
  attachments: [
    Hanami::Mailer.file("invoice-123.pdf", pdf_bytes, content_type: "application/pdf")
  ]
)
```

### Delivery options

Delivery options are delivery-method-specific parameters that customize how a message is sent. Their blocks receive arguments [like every other block](#accessing-input-and-exposures-in-blocks), and the resulting options are passed through to the delivery method on the `Message` object.

A third-party email service might use these for scheduled sending, priority levels, or tracking.

```ruby
class CampaignMailer < Hanami::Mailer
  from "campaigns@example.com"
  to { |recipient:| recipient[:email] }
  subject "Special Offer"

  # Static delivery option
  delivery_option :track_opens, true

  # Dynamic delivery option
  delivery_option(:send_at) { |scheduled_time:| scheduled_time }
  delivery_option(:tags) { |campaign:| ["campaign-#{campaign[:id]}"] }
end

mailer = CampaignMailer.new(delivery_method: postmark_delivery)
mailer.deliver(
  recipient: {email: "user@example.com"},
  campaign: {id: 42},
  scheduled_time: Time.now + 3600
)
```

The delivery method receives these options via `message.delivery_options` and can act on them however it sees fit.

### Inheritance

Mailers support inheritance, which is useful for sharing common configuration.

```ruby
class ApplicationMailer < Hanami::Mailer
  from "noreply@example.com"
  config.attachment_paths = ["app/attachments"]
end

class WelcomeMailer < ApplicationMailer
  to { |user:| user[:email] }
  subject "Welcome!"

  expose :user
end

class NewsletterMailer < ApplicationMailer
  to { |subscriber:| subscriber[:email] }
  subject "Weekly Newsletter"

  expose :subscriber

  attachment "terms.pdf"
end
```

Headers, exposures, attachments, and delivery options are all inherited and can be extended in subclasses.

### Delivery methods

`Hanami::Mailer` expects the delivery method to be provided as a `delivery_method:` dependency at initialization.

Every delivery method must respond to `#call(message)` and return a `Delivery::Result`.

#### Test delivery (default)

The test delivery method stores results in memory. It's the default when no delivery method is specified.

```ruby
mailer = WelcomeMailer.new
result = mailer.deliver(user: user)

result.success?       # => true
result.message        # => the Hanami::Mailer::Message that was delivered

# Inspect all deliveries via the mailer's delivery method instance
mailer.delivery_method.deliveries       # => [result, ...]
mailer.delivery_method.deliveries.size  # => 1
mailer.delivery_method.clear            # reset between tests
```

#### SMTP delivery

For production use, provide an SMTP delivery method.

```ruby
smtp = Hanami::Mailer::Delivery::SMTP.new(
  address: "smtp.example.com",
  port: 587,
  user_name: ENV["SMTP_USERNAME"],
  password: ENV["SMTP_PASSWORD"],
  authentication: :plain,
  enable_starttls_auto: true
)

mailer = WelcomeMailer.new(delivery_method: smtp)
result = mailer.deliver(user: user)

result.success?   # => true if SMTP accepted the message
result.response   # => the Mail::Message object
result.error      # => nil on success, the exception on failure
```

#### Custom delivery methods

Implement your own delivery method by creating a class that responds to `#call(message)` and returns a `Delivery::Result`.

```ruby
class MyApiDelivery
  def call(message)
    response = SomeEmailApi.send(
      from: message.from,
      to: message.to,
      subject: message.subject,
      html: message.html_body,
      options: message.delivery_options
    )

    Hanami::Mailer::Delivery::Result.new(
      message: message,
      response: response,
      success: response.ok?
    )
  rescue => error
    Hanami::Mailer::Delivery::Result.new(
      message: message,
      success: false,
      error: error
    )
  end
end
```

Third-party delivery methods can subclass `Delivery::Result` to expose service-specific attributes.

```ruby
class Postmark::Result < Hanami::Mailer::Delivery::Result
  attr_reader :message_id, :submitted_at

  def initialize(message_id:, submitted_at: nil, **)
    super(**)
    @message_id = message_id
    @submitted_at = submitted_at
  end
end
```

### Preparing messages without delivering

Use `prepare` to build a `Message` without sending it. This is useful for inspection, queuing, or delivering later through a different method.

```ruby
class WelcomeMailer < Hanami::Mailer
  from "welcome@example.com"
  to { |user:| user[:email] }
  subject { |user:| "Welcome, #{user[:name]}!" }

  expose :user
end

mailer = WelcomeMailer.new
message = mailer.prepare(user: {name: "Alice", email: "alice@example.com"})

message.from       # => ["welcome@example.com"]
message.to         # => ["alice@example.com"]
message.subject    # => "Welcome, Alice!"
message.html_body  # => rendered HTML (if templates exist)
message.text_body  # => rendered text (if templates exist)

# Deliver the prepared message directly through a delivery method
smtp = Hanami::Mailer::Delivery::SMTP.new(address: "smtp.example.com")
smtp.call(message)
```

### Previewing messages

Delivery methods expose a `preview` hook that returns a prepared message without sending it. The default (and test) delivery method returns the message unchanged; a third-party delivery method can override `preview` to apply service-specific logic, such as resolving a template through a remote API.

Use `#preview` to prepare the message and run it through the delivery method's hook in one step. It takes the same arguments as `#deliver` and `#prepare`:

```ruby
mailer = WelcomeMailer.new

preview = mailer.preview(user: {name: "Alice", email: "alice@example.com"})
```

When you already hold a prepared message, you can call the delivery method's hook directly instead:

```ruby
message = mailer.prepare(user: {name: "Alice", email: "alice@example.com"})

preview = mailer.delivery_method.preview(message)
```

### Using a custom view class

By default mailers render using a subclass of `Hanami::View`. To inherit from another view class, configure it via `config.view_class`. The mailer's view will inherit from this and use its configuration — context, parts, scopes, paths, helpers, and so on. This is how mailers in a Hanami app pick up the app's standard view behaviour.

```ruby
class ReportMailer < Hanami::Mailer
  config.view_class = MyApp::View

  from "reports@example.com"
  to { |user:| user[:email] }
  subject "Monthly Report"

  expose :user
end
```

Because template paths are inherited from the configured view class, you typically don't need to set `config.paths` or yourself in this case.

### Custom rendering without Hanami View

If you don't use Hanami View, override the internal rendering methods. These are also a hook for integrations with other rendering systems.

```ruby
class CustomMailer < Hanami::Mailer
  from "custom@example.com"
  to { |user:| user[:email] }
  subject "Custom Email"

  expose :user

  private

  def render_view(format, input)
    user = input[:user]

    case format
    when :html
      <<~HTML
        <html>
          <body>
            <h1>Hello, #{user[:name]}!</h1>
          </body>
        </html>
      HTML
    when :text
      "Hello, #{user[:name]}!"
    end
  end
end
```

If Hanami View is installed but you don't want mailers building a view from it automatically, turn off auto view-building with `config.integrate_view = false`. Your overridden `render_view` then takes full responsibility for rendering.

## Links

- [User documentation](https://hanamirb.org)
- [API documentation](http://rubydoc.info/gems/hanami-mailer)


## License

See `LICENSE` file.
