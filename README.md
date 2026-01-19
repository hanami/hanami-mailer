# Hanami::Mailer

Email delivery for Hanami applications and Ruby projects.

## Version

This is `hanami-mailer` 2.0, a complete rewrite designed for simplicity, flexibility, and seamless integration with Hanami 2.0.

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

### Basic Mailer

Define a mailer class by inheriting from `Hanami::Mailer`:

```ruby
class WelcomeMailer < Hanami::Mailer
  from "noreply@example.com"
  to "user@example.com"
  subject "Welcome to our app!"
end

# Deliver the email
mailer = WelcomeMailer.new
mailer.deliver
```

### Dynamic Recipients and Metadata

Use blocks or procs to compute email metadata dynamically:

```ruby
class UserMailer < Hanami::Mailer
  from "notifications@example.com"
  to { |locals| locals[:user][:email] }
  subject { |locals| "Hello, #{locals[:user][:name]}!" }

  expose :user
end

# Deliver with data
mailer = UserMailer.new
mailer.deliver(user: { name: "Alice", email: "alice@example.com" })
```

### Exposures

Use exposures to prepare data for your email templates:

```ruby
class OrderConfirmationMailer < Hanami::Mailer
  from "orders@example.com"
  to { |locals| locals[:customer][:email] }
  subject "Order Confirmation"

  expose :customer
  expose :order
  expose :total do |order:|
    order[:items].sum { |item| item[:price] }
  end
end
```

Exposures support:
- Simple value passing: `expose :user`
- Computed values with blocks: `expose :total { ... }`
- Dependencies on other exposures: `expose :total do |order:| ... end`
- Default values: `expose :greeting, default: "Hello"`

### Attachments

#### Static Attachments

Configure `attachment_paths` to specify where static attachment files are located. You **must** configure `attachment_paths` for static attachments, otherwise a `MissingAttachmentError` will be raised:

```ruby
class InvoiceMailer < Hanami::Mailer
  from "billing@example.com"
  to { |locals| locals[:customer][:email] }
  subject "Your Invoice"

  # Configure where to find attachment files
  config.attachment_paths = [File.join(__dir__, "..", "attachments")]

  attachment "terms.pdf"
  attachment "company-logo.png"
end
```

The mailer will search for files in the configured `attachment_paths` and automatically read their content. If a file cannot be found, a `MissingAttachmentError` is raised.

**Directory structure:**
```
app/
├── mailers/
│   └── invoice_mailer.rb
└── attachments/
    ├── terms.pdf
    └── company-logo.png
```

You can configure multiple paths in a base mailer class:

```ruby
class ApplicationMailer < Hanami::Mailer
  config.attachment_paths = [
    File.join(__dir__, "..", "attachments"),
    File.join(__dir__, "..", "assets", "pdfs")
  ]
end

class InvoiceMailer < ApplicationMailer
  from "billing@example.com"
  to { |locals| locals[:customer][:email] }
  subject "Your Invoice"

  attachment "terms.pdf"  # Found in app/attachments/terms.pdf
end
```

#### Dynamic Attachments

**You must use the `file` helper** to create dynamic attachments.

```ruby
class ReportMailer < Hanami::Mailer
  from "reports@example.com"
  to { |locals| locals[:user][:email] }
  subject "Monthly Report"

  expose :report_id

  attachment do |report_id:|
    file(
      "report-#{report_id}.pdf",
      generate_pdf(report_id),
      content_type: "application/pdf"
    )
  end

  private

  def generate_pdf(report_id)
    # Generate PDF content
  end
end
```

#### Multiple Attachments

```ruby
class NewsletterMailer < Hanami::Mailer
  from "news@example.com"
  to { |locals| locals[:subscriber][:email] }
  subject "Weekly Newsletter"

  attachment "header.png", inline: true
  attachment "footer.png", inline: true
  
  attachment do
    file("newsletter.pdf", generate_newsletter_pdf)
  end
end
```

#### Inline Attachments

Inline attachments are useful for embedding images in HTML emails:

```ruby
class MarketingMailer < Hanami::Mailer
  from "marketing@example.com"
  to { |locals| locals[:recipient] }
  subject "Special Offer"

  attachment "logo.png", inline: true
end
```

Inline attachments get a `content_id` that can be referenced in your HTML templates.

#### The `file` Helper

The `file` helper is **required** for creating dynamic attachments. It returns an `AttachmentData` object that validates required fields and provides a clean, structured API:

```ruby
class InvoiceMailer < Hanami::Mailer
  from "billing@example.com"
  to { |customer:| customer[:email] }
  subject "Invoice"

  expose :invoice

  attachment :invoice_pdf

  private

  def invoice_pdf(invoice:)
    # Returns an AttachmentData object with validation
    file(
      "invoice-#{invoice[:number]}.pdf",
      generate_pdf_content(invoice),
      content_type: "application/pdf"
    )
  end

  def generate_pdf_content(invoice)
    # PDF generation logic
  end
end
```

**Why `file` is required:**
- Validates that filename and content are present
- Clear, readable API
- Type-safe - no raw hashes allowed
- Supports all attachment options (`content_type`, `inline`)
- Returns proper `AttachmentData` objects instead of primitive hashes

**Note:** Returning raw hashes from attachment blocks will raise an `ArgumentError`. Always use the `file` helper.

### View Integration

Hanami::Mailer 2.0 integrates with Hanami::View for rendering email templates:

```ruby
# In app/views/mailers/welcome_view.rb
module Views
  module Mailers
    class WelcomeView < Hanami::View
      expose :user
      expose :confirmation_url
    end
  end
end

# In app/mailers/welcome_mailer.rb
module Mailers
  class WelcomeMailer < Hanami::Mailer
    from "noreply@example.com"
    to { |locals| locals[:user].email }
    subject "Welcome!"

    def initialize(view: Views::Mailers::WelcomeView.new)
      super
    end
  end
end

# Deliver
mailer = Mailers::WelcomeMailer.new
mailer.deliver(user: user, confirmation_url: url)
```

### Configuration

Configure Hanami::Mailer globally:

```ruby
Hanami::Mailer.configure do |config|
  config.default_from = "noreply@example.com"
  config.default_charset = "UTF-8"
end
```

#### Configuration Options

- `default_from` - Default sender address for all mailers
- `default_charset` - Default character encoding (default: "UTF-8")
- `attachment_paths` - Array of paths to search for static attachment files

### Delivery Methods

Delivery methods are injected when creating a mailer instance, making them easy to test and swap out.

#### Test Delivery (Default)

The test delivery method stores emails in memory for testing. It's the default if no delivery is specified:

```ruby
# Uses test delivery by default
mailer = WelcomeMailer.new
mailer.deliver(user: user)

# Check delivered emails
deliveries = Hanami::Mailer::Delivery::Test.deliveries
expect(deliveries.size).to eq(1)
```

In tests:

```ruby
RSpec.describe WelcomeMailer do
  before do
    Hanami::Mailer::Delivery::Test.clear
  end

  it "sends welcome email" do
    mailer = WelcomeMailer.new
    mailer.deliver(user: user)

    deliveries = Hanami::Mailer::Delivery::Test.deliveries
    expect(deliveries.size).to eq(1)
    
    mail = deliveries.first
    expect(mail.to).to include(user.email)
    expect(mail.subject).to eq("Welcome!")
  end
end
```

#### SMTP Delivery

For production use, inject an SMTP delivery instance:

```ruby
smtp_delivery = Hanami::Mailer::Delivery::Smtp.new(
  address: "smtp.example.com",
  port: 587,
  domain: "example.com",
  user_name: ENV["SMTP_USERNAME"],
  password: ENV["SMTP_PASSWORD"],
  authentication: :plain,
  enable_starttls_auto: true
)

mailer = WelcomeMailer.new(delivery: smtp_delivery)
mailer.deliver(user: user)
```

In a Hanami app, you can register the delivery method as a dependency:

```ruby
# config/app.rb
module MyApp
  class App < Hanami::App
    config.after_initialize do
      register "mailers.delivery", Hanami::Mailer::Delivery::Smtp.new(
        address: ENV["SMTP_ADDRESS"],
        port: ENV["SMTP_PORT"],
        # ... other options
      )
    end
  end
end

# Then inject it
class WelcomeMailer < Hanami::Mailer
  include Deps["mailers.delivery"]
  
  def initialize(delivery:, **deps)
    super(delivery: delivery)
  end
end
```

#### Custom Delivery Methods

Implement your own delivery method by creating a class that responds to `#call`:

```ruby
class CustomDelivery
  def call(message)
    mail = message.to_mail
    # Custom delivery logic (e.g., send via API)
    mail
  end
end

# Inject it
mailer = WelcomeMailer.new(delivery: CustomDelivery.new)
mailer.deliver(user: user)
```

### Preparing vs. Delivering

Sometimes you want to build a message without immediately delivering it:

```ruby
mailer = WelcomeMailer.new

# Build the message without delivering
message = mailer.prepare(user: user)

# Inspect the message
message.to      # => ["user@example.com"]
message.subject # => "Welcome!"

# Deliver later
mail = mailer.deliver(user: user)
```

### Advanced Features

#### Multiple Recipients

```ruby
class AnnouncementMailer < Hanami::Mailer
  from "announcements@example.com"
  to ["team@example.com", "managers@example.com"]
  cc "ceo@example.com"
  bcc "archive@example.com"
  subject "Company Update"
end
```

#### Reply-To

```ruby
class SupportMailer < Hanami::Mailer
  from "noreply@example.com"
  reply_to "support@example.com"
  to { |locals| locals[:user][:email] }
  subject "Support Ticket Created"
end
```

#### Custom Charset

```ruby
class JapaneseMailer < Hanami::Mailer
  from "info@example.jp"
  to { |locals| locals[:recipient] }
  subject "お知らせ"
end

mailer = JapaneseMailer.new
mailer.deliver(recipient: "user@example.jp", charset: "ISO-2022-JP")
```

#### Inheritance

Mailers support inheritance, which is useful for sharing common configuration:

```ruby
class ApplicationMailer < Hanami::Mailer
  from "noreply@example.com"
end

class WelcomeMailer < ApplicationMailer
  to { |locals| locals[:user].email }
  subject "Welcome!"
  
  expose :user
end

class NewsletterMailer < ApplicationMailer
  to { |locals| locals[:subscriber].email }
  subject "Weekly Newsletter"
  
  expose :subscriber
end
```

## Testing

### RSpec

```ruby
RSpec.describe WelcomeMailer do
  before do
    Hanami::Mailer::Delivery::Test.clear
  end

  describe "#deliver" do
    it "sends welcome email" do
      user = { name: "Alice", email: "alice@example.com" }
      
      mailer = WelcomeMailer.new
      mailer.deliver(user: user)

      deliveries = Hanami::Mailer::Delivery::Test.deliveries
      expect(deliveries.size).to eq(1)
      
      mail = deliveries.first
      expect(mail.from).to eq(["noreply@example.com"])
      expect(mail.to).to eq(["alice@example.com"])
      expect(mail.subject).to eq("Welcome!")
    end
  end

  describe "#prepare" do
    it "builds message without delivering" do
      user = { name: "Bob", email: "bob@example.com" }
      
      mailer = WelcomeMailer.new
      message = mailer.prepare(user: user)

      expect(message).to be_a(Hanami::Mailer::Message)
      expect(message.to).to eq(["bob@example.com"])
      
      # Message was not delivered
      expect(Hanami::Mailer::Delivery::Test.deliveries).to be_empty
    end
  end
end
```

### Minitest

```ruby
class WelcomeMailerTest < Minitest::Test
  def setup
    Hanami::Mailer::Delivery::Test.clear
  end

  def test_delivers_welcome_email
    user = { name: "Alice", email: "alice@example.com" }
    
    mailer = WelcomeMailer.new
    mailer.deliver(user: user)

    deliveries = Hanami::Mailer::Delivery::Test.deliveries
    assert_equal 1, deliveries.size
    
    mail = deliveries.first
    assert_equal ["noreply@example.com"], mail.from
    assert_equal ["alice@example.com"], mail.to
    assert_equal "Welcome!", mail.subject
  end
end
```

## Architecture

Hanami::Mailer 2.0 is built with a clean separation of concerns:

- **Mailer**: DSL for defining email metadata and exposures
- **Message**: Immutable email message representation
- **Delivery**: Pluggable delivery backends
- **Exposures**: Borrowed from Hanami::View for consistent data preparation
- **Attachments**: Flexible attachment handling with support for static and dynamic files

## Upgrading from 1.x

Hanami::Mailer 2.0 is a complete rewrite. Key changes:

### Removed Features
- Configuration finalization (no longer needed)
- Template inference from mailer name (use Hanami::View instead)
- `before` callbacks (use exposures and regular methods)
- Global configuration through `Hanami::Mailer::Configuration` class

### New Features
- Simplified DSL
- Better integration with Hanami::View 2.x
- Exposure system for data preparation
- Cleaner attachment API
- Pluggable delivery methods
- No need for configuration finalization

### Migration Guide

**1.x:**
```ruby
class WelcomeMailer < Hanami::Mailer
  from    'noreply@example.com'
  to      ->(locals) { locals.fetch(:user).email }
  subject 'Welcome'
  
  before do |mail, locals|
    mail.attachments["welcome.pdf"] = File.read("welcome.pdf")
  end
end

configuration = Hanami::Mailer::Configuration.new do |config|
  config.delivery_method = :smtp, address: "smtp.example.com"
end

Hanami::Mailer.finalize(configuration)

mailer = WelcomeMailer.new(configuration: configuration)
mailer.deliver(user: user)
```

**2.x:**
```ruby
class WelcomeMailer < Hanami::Mailer
  from "noreply@example.com"
  to { |locals| locals[:user].email }
  subject "Welcome"
  
  expose :user
  attachment "welcome.pdf"
end

# Inject delivery method
smtp_delivery = Hanami::Mailer::Delivery::Smtp.new(
  address: "smtp.example.com"
)

mailer = WelcomeMailer.new(delivery: smtp_delivery)
mailer.deliver(user: user)
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/hanami/mailer.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Hanami::Mailer project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/hanami/mailer/blob/main/CODE_OF_CONDUCT.md).

# TODO

- allow use of inflector for header capitalisation
