Email delivery for Hanami applications and Ruby projects.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "hanami-mailer"
```

And then execute:

```bash
$ bundle install
```

## Usage

### Basic mailer

The simplest mailer with static headers.

```ruby
class WelcomeMailer < Hanami::Mailer
  from "noreply@example.com"
  to "user@example.com"
  subject "Welcome to our app!"
end

mailer = WelcomeMailer.new
mailer.deliver
```

**Templates:**

`app/templates/mailers/welcome.html.erb`:

```erb
<h1>Welcome to our app!</h1>
```

`app/templates/mailers/welcome.txt.erb`:

```erb
Welcome to our app!
```

### Dynamic headers and exposures

Use blocks to compute headers dynamically based on input data, just like we do for `expose` in Hanami View.

`expose` itself is also available. We use Hanami View by default to render the mail bodies, and `expose` passes values to the view templates.

```ruby
class UserMailer < Hanami::Mailer
  from "notifications@example.com"
  to { |user:| user[:email] }
  subject { |user:| "Hello, #{user[:name]}!" }

  expose :user
end

mailer = UserMailer.new
mailer.deliver(user: {name: "Alice", email: "alice@example.com"})
```

**Templates:**

`app/templates/mailers/user_mailer.html.erb`:

```erb
<h1>Hello, <%= user[:name] %>!</h1>
```

`app/templates/mailers/user_mailer.txt.erb`:

```erb
Hello, <%= user[:name] %>!
```

Exposures support:

- Simple value passing: `expose :user`
- Computed values with blocks: `expose(:total) { |order:| order[:items].sum { |item| item[:price] } }`
- Dependencies on other exposures: `expose(:greeting) { |user:| "Hello, #{user[:name]}!" }`
- Default values: `expose :greeting, default: "Hello"`
- Private exposures (available to other exposures but not to templates): `expose :raw_data, private: true`

### Standard and custom email headers

Aside from the standard headers (which have their own dedicated convenience methods), you can add additional custom headers.

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

### Static attachments from files

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

You can configure multiple attachment paths in a base mailer class:

```ruby
class ApplicationMailer < Hanami::Mailer
  config.attachment_paths = [
    "app/attachments",
    "app/assets/pdfs"
  ]
end
```

If a file cannot be found in any of the configured paths, a `MissingAttachmentError` is raised.

### Dynamic attachments from blocks

Return one or more attachments from an `attachment` block, which processes arguments in the same way as `expose` and `header`. Use the `file` helper to create attachment objects.

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

You can also return multiple attachments from a single block:

```ruby
attachment do |documents:|
  documents.map do |doc|
    file(doc[:name], doc[:content])
  end
end
```

Or use a named instance method instead of a block:

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

### Inline attachments (for embedding images in HTML)

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

In your HTML template, reference inline attachments using `cid:`:

```html
<img src="cid:header-image.png" alt="Newsletter Header">
```

Static attachments can also be made inline:

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

Delivery options are delivery-method-specific parameters that customize how a message is sent. They are evaluated the same way as headers and exposures, then passed through to the delivery method on the `Message` object.

A third-party email service might use these for scheduled sending, priority levels, or tracking:

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

### Delivery methods

`Hanami::Mailer` expects the delivery method to be provided as a `delivery_method:` dependency at initialization.

Every delivery method must respond to `#call(message)` and return a `Delivery::Result`.

#### Test delivery (default)

The test delivery method stores results in memory. It's the default when no delivery method is specified:

```ruby
mailer = WelcomeMailer.new
result = mailer.deliver(user: user)

result.success?       # => true
result.message        # => the Hanami::Mailer::Message that was delivered

# Inspect all deliveries
Hanami::Mailer::Delivery::Test.deliveries       # => [result, ...]
Hanami::Mailer::Delivery::Test.deliveries.size   # => 1
Hanami::Mailer::Delivery::Test.clear             # reset between tests
```

#### SMTP delivery

For production use, provide an SMTP delivery method:

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

Implement your own delivery method by creating a class that responds to `#call(message)` and returns a `Delivery::Result`:

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

Third-party delivery methods can subclass `Delivery::Result` to expose service-specific attributes:

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

#### Wiring delivery in a Hanami app

Below is an example of how you could wire up a delivery method in a Hanami app. (A more streamlined integration experience is planned for future work.)

```ruby
# In your Hanami app, configure a delivery method provider
Hanami.app.register_provider :mailer do
  start do
    require "hanami/mailer"

    register "mailer.delivery_method", Hanami::Mailer::Delivery::SMTP.new(
      address: target[:settings].smtp_address,
      port: target[:settings].smtp_port,
      user_name: target[:settings].smtp_username,
      password: target[:settings].smtp_password,
      authentication: :plain,
      enable_starttls_auto: true
    )
  end
end

class OrderMailer < Hanami::Mailer
  include Deps["mailer.delivery_method"]

  from "orders@example.com"
  to { |customer:| customer[:email] }
  subject "Order Confirmation"

  expose :customer
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

### Inheritance

Mailers support inheritance, which is useful for sharing common configuration:

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

### Custom rendering without Hanami View

If you don't use Hanami View, override the private rendering methods. This is also a hook for integration with other rendering systems like Phlex.

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

### Testing

#### Checking deliveries

```ruby
RSpec.describe OrderConfirmationMailer do
  before { Hanami::Mailer::Delivery::Test.clear }

  it "sends confirmation email" do
    mailer = OrderConfirmationMailer.new
    result = mailer.deliver(order: {id: 123}, customer: {email: "test@example.com"})

    # Check the result directly
    expect(result.success?).to be true
    expect(result.message.to).to include("test@example.com")
    expect(result.message.subject).to include("123")

    # Or inspect all deliveries
    expect(Hanami::Mailer::Delivery::Test.deliveries.size).to eq(1)
  end
end
```

#### Inspecting prepared messages

```ruby
RSpec.describe WelcomeMailer do
  it "builds the expected message" do
    mailer = WelcomeMailer.new
    message = mailer.prepare(user: {name: "Alice", email: "alice@example.com"})

    expect(message.from).to eq(["noreply@example.com"])
    expect(message.to).to eq(["alice@example.com"])
    expect(message.subject).to eq("Welcome, Alice!")
    expect(message.html_body).to include("Hello")

    # No email was delivered
    expect(Hanami::Mailer::Delivery::Test.deliveries).to be_empty
  end
end
```
