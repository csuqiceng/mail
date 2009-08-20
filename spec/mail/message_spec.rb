# encoding: utf-8
require File.dirname(__FILE__) + '/../spec_helper'

require 'mail'

describe Mail::Message do
  
  def basic_email
    "To: mikel\r\nFrom: bob\r\nSubject: Hello!\r\n\r\nemail message\r\n"
  end
  
  describe "initialization" do
    
    describe "plain text emails" do
    
      it "should instantiate empty" do
        Mail::Message.new.class.should == Mail::Message
      end
    
      it "should instantiate with a string" do
        Mail::Message.new(basic_email).class.should == Mail::Message
      end
    
      it "should allow us to pass it a block" do
        mail = Mail::Message.new do
          from 'mikel@me.com'
          to 'lindsaar@you.com'
        end
        mail.from.addresses.should == ['mikel@me.com']
        mail.to.addresses.should == ['lindsaar@you.com']
      end
    
      it "should initialize a body and header class even if called with nothing to begin with" do
        mail = Mail::Message.new
        mail.header.class.should == Mail::Header
        mail.body.class.should == Mail::Body
      end
    
      it "should be able to parse a basic email" do
        doing { Mail::Message.new(File.read(fixture('emails', 'plain_emails', 'basic_email'))) }.should_not raise_error
      end

      it "should be able to parse every email example we have without raising an exception" do
        emails = Dir.glob( fixture('emails/**/*') ).delete_if { |f| File.directory?(f) }
        STDERR.stub!(:puts) # Don't want to get noisy about any warnings
        emails.each do |email|
          doing { Mail::Message.new(File.read(email)) }.should_not raise_error
        end
      end

      it "should raise a warning (and keep parsing) on having non US-ASCII characters in the header" do
        STDERR.should_receive(:puts)
        Mail::Message.new(File.read(fixture('emails', 'plain_emails', 'raw_email_string_in_date_field')))
      end

      it "should raise a warning (and keep parsing) on having an incorrectly formatted header" do
        STDERR.should_receive(:puts).with("WARNING: Could not parse (and so ignorning) 'quite Delivered-To: xxx@xxx.xxx'")
        Mail::Message.new(File.read(fixture('emails', 'plain_emails', 'raw_email_incorrect_header')))
      end

      it "should read in an email message and basically parse it" do
        mail = Mail::Message.new(File.read(fixture('emails', 'plain_emails', 'basic_email')))
        mail.to.formatted.should == ["Mikel Lindsaar <raasdnil@gmail.com>"]
      end

    end

  end
  
  describe "envelope line handling" do
    it "should respond to 'envelope from'" do
      Mail::Message.new.should respond_to(:envelope_from)
    end
    
    it "should strip off the envelope from field if present" do
      message = Mail::Message.new(File.read(fixture('emails', 'plain_emails', 'raw_email')))
      message.envelope_from.should == "jamis_buck@byu.edu"
      message.envelope_date.should == ::DateTime.parse("Mon May  2 16:07:05 2005")
    end
    
    it "should strip off the envelope from field if present" do
      message = Mail::Message.new(File.read(fixture('emails', 'plain_emails', 'raw_email')))
      message.raw_envelope.should == "jamis_buck@byu.edu Mon May  2 16:07:05 2005"
      message.from.formatted.should == ["Jamis Buck <jamis@37signals.com>"]
    end

    it "should not cause any problems if there is no envelope from present" do
      message = Mail::Message.new(File.read(fixture('emails', 'plain_emails', 'basic_email')))
      message.from.formatted.should == ["Mikel Lindsaar <test@lindsaar.net>"]
    end

  end
  
  describe "accepting a plain text string email" do

    it "should accept some email text to parse and return an email" do
      mail = Mail::Message.new(basic_email)
      mail.class.should == Mail::Message
    end

    it "should set a raw source instance variable to equal the passed in message" do
      mail = Mail::Message.new(basic_email)
      mail.raw_source.should == basic_email.strip
    end

    it "should set the raw source instance variable to '' if no message is passed in" do
      mail = Mail::Message.new
      mail.raw_source.should == ""
    end
  
    it "should give the header class the header to parse" do
      header = Mail::Header.new("To: mikel\r\nFrom: bob\r\nSubject: Hello!")
      Mail::Header.should_receive(:new).with("To: mikel\r\nFrom: bob\r\nSubject: Hello!").and_return(header)
      mail = Mail::Message.new(basic_email)
    end

    it "should give the header class the header to parse even if there is no body" do
      header = Mail::Header.new("To: mikel\r\nFrom: bob\r\nSubject: Hello!")
      Mail::Header.should_receive(:new).with("To: mikel\r\nFrom: bob\r\nSubject: Hello!").and_return(header)
      mail = Mail::Message.new("To: mikel\r\nFrom: bob\r\nSubject: Hello!")
    end
  
    it "should give the body class the body to parse" do
      body = Mail::Body.new("email message")
      Mail::Body.should_receive(:new).with("email message").and_return(body)
      mail = Mail::Message.new(basic_email)
    end
  
    it "should still ask the body for a new instance even though these is nothing to parse, yet" do
      Mail::Body.should_receive(:new)
      mail = Mail::Message.new("To: mikel\r\nFrom: bob\r\nSubject: Hello!")
    end

    it "should give the header the part before the line without spaces and the body the part without" do
      header = Mail::Header.new("To: mikel")
      body = Mail::Body.new("G'Day!")
      Mail::Header.should_receive(:new).with("To: mikel").and_return(header)
      Mail::Body.should_receive(:new).with("G'Day!").and_return(body)
      mail = Mail::Message.new("To: mikel\r\n\r\nG'Day!")
    end
  
    it "should give allow for whitespace on the gap line between header and body" do
      header = Mail::Header.new("To: mikel")
      body = Mail::Body.new("G'Day!")
      Mail::Header.should_receive(:new).with("To: mikel").and_return(header)
      Mail::Body.should_receive(:new).with("G'Day!").and_return(body)
      mail = Mail::Message.new("To: mikel\r\n   		  \r\nG'Day!")
    end

    it "should allow for whitespace at the start of the email" do
      mail = Mail.new("\r\n\r\nFrom: mikel\r\n\r\nThis is the body")
      mail.from.value.should == 'mikel'
      mail.body.to_s.should == 'This is the body'
    end

  end
  
  describe "directly setting values of a message" do

    before(:each) do
      @mail = Mail::Message.new
    end

    describe "accessing fields directly" do
      
      it "should allow you to grab field objects if you really want to" do
        @mail.header_fields.class.should == Array
      end
      
      it "should give you back the fields in the header" do
        @mail['bar'] = 'abcd'
        @mail.header_fields.length.should == 1
        @mail['foo'] = '4321'
        @mail.header_fields.length.should == 2
      end
      
      it "should delete a field if it is set to nil" do
        @mail['foo'] = '4321'
        @mail.header_fields.length.should == 1
        @mail['foo'] = nil
        @mail.header_fields.length.should == 0
      end
    end

    describe "with :method=" do
      it "should return the to field" do
        @mail.to = "mikel"
        @mail.to.addresses.should == ["mikel"]
      end

      it "should return the from field" do
        @mail.from = "bob"
        @mail.from.addresses.should == ["bob"]
      end

      it "should return the subject" do
        @mail.subject = "Hello!"
        @mail.subject.to_s.should == "Hello!"
      end

      it "should return the body" do
        @mail.body = "email message\r\n"
        @mail.body.to_s.should == "email message\r\n"
      end
    end
    
    describe "with :method(value)" do
      it "should return the to field" do
        @mail.to "mikel"
        @mail.to.addresses.should == ["mikel"]
      end

      it "should return the from field" do
        @mail.from "bob"
        @mail.from.addresses.should == ["bob"]
      end

      it "should return the subject" do
        @mail.subject "Hello!"
        @mail.subject.to_s.should == "Hello!"
      end

      it "should return the body" do
        @mail.body "email message\r\n"
        @mail.body.to_s.should == "email message\r\n"
      end
    end
    
    describe "setting arbitrary headers" do
      it "should allow you to set them" do
        doing {@mail['foo'] = 1234}.should_not raise_error
      end
      
      it "should allow you to read arbitrary headers" do
        @mail['foo'] = 1234
        @mail['foo'].value.should == '1234'
      end
      
      it "should instantiate a new Header" do
        @mail['foo'] = 1234
        @mail.header_fields.first.class.should == Mail::Field
      end
    end
    
    describe "setting headers" do
      
      it "should accept them in block form" do
        message = Mail.new do
          bcc           'mikel@bcc.lindsaar.net'
          cc            'mikel@cc.lindsaar.net'
          comments      'this is a comment'
          date          '12 Aug 2009 00:00:01 GMT'
          from          'mikel@from.lindsaar.net'
          in_reply_to   '<1234@in_reply_to.lindsaar.net>'
          keywords      'test, "of the new mail", system'
          message_id    '<1234@message_id.lindsaar.net>'
          received      '12 Aug 2009 00:00:02 GMT'
          references    '<1234@references.lindsaar.net>'
          reply_to      'mikel@reply-to.lindsaar.net'
          resent_bcc    'mikel@resent-bcc.lindsaar.net'
          resent_cc     'mikel@resent-cc.lindsaar.net'
          resent_date   '12 Aug 2009 00:00:03 GMT'
          resent_from   'mikel@resent-from.lindsaar.net'
          resent_message_id '<1234@resent_message_id.lindsaar.net>'
          resent_sender 'mikel@resent-sender.lindsaar.net'
          resent_to     'mikel@resent-to.lindsaar.net'
          sender        'mikel@sender.lindsaar.net'
          subject       'Hello there Mikel'
          to            'mikel@to.lindsaar.net'
          content_type  'text/plain; charset=UTF-8'
          content_transfer_encoding '7bit'
          content_description       'This is a test'
          content_id                '<1234@message_id.lindsaar.net>'
          mime_version  '1.0'
          body          'This is a body of text'
        end
        
        message.bcc.to_s.should           == 'mikel@bcc.lindsaar.net'
        message.cc.to_s.should            == 'mikel@cc.lindsaar.net'
        message.comments.to_s.should      == 'this is a comment'
        message.date.to_s.should          == '12 Aug 2009 00:00:01 GMT'
        message.from.to_s.should          == 'mikel@from.lindsaar.net'
        message.in_reply_to.to_s.should   == '<1234@in_reply_to.lindsaar.net>'
        message.keywords.to_s.should      == 'test, "of the new mail", system'
        message.message_id.to_s.should    == '<1234@message_id.lindsaar.net>'
        message.received.to_s.should      == '12 Aug 2009 00:00:02 GMT'
        message.references.to_s.should    == '<1234@references.lindsaar.net>'
        message.reply_to.to_s.should      == 'mikel@reply-to.lindsaar.net'
        message.resent_bcc.to_s.should    == 'mikel@resent-bcc.lindsaar.net'
        message.resent_cc.to_s.should     == 'mikel@resent-cc.lindsaar.net'
        message.resent_date.to_s.should   == '12 Aug 2009 00:00:03 GMT'
        message.resent_from.to_s.should   == 'mikel@resent-from.lindsaar.net'
        message.resent_message_id.to_s.should == '<1234@resent_message_id.lindsaar.net>'
        message.resent_sender.to_s.should == 'mikel@resent-sender.lindsaar.net'
        message.resent_to.to_s.should     == 'mikel@resent-to.lindsaar.net'
        message.sender.to_s.should        == 'mikel@sender.lindsaar.net'
        message.subject.to_s.should       == 'Hello there Mikel'
        message.to.to_s.should            == 'mikel@to.lindsaar.net'
        message.content_type.to_s.should              == 'text/plain; charset=UTF-8'
        message.content_transfer_encoding.to_s.should == '7bit'
        message.content_description.to_s.should       == 'This is a test'
        message.content_id.to_s.should                == '<1234@message_id.lindsaar.net>'
        message.mime_version.to_s.should              == '1.0'
        message.body.to_s.should          == 'This is a body of text'
      end

      it "should accept them in assignment form" do
        message = Mail.new
        message.bcc =           'mikel@bcc.lindsaar.net'
        message.cc =            'mikel@cc.lindsaar.net'
        message.comments =      'this is a comment'
        message.date =          '12 Aug 2009 00:00:01 GMT'
        message.from =          'mikel@from.lindsaar.net'
        message.in_reply_to =   '<1234@in_reply_to.lindsaar.net>'
        message.keywords =      'test, "of the new mail", system'
        message.message_id =    '<1234@message_id.lindsaar.net>'
        message.received =      '12 Aug 2009 00:00:02 GMT'
        message.references =    '<1234@references.lindsaar.net>'
        message.reply_to =      'mikel@reply-to.lindsaar.net'
        message.resent_bcc =    'mikel@resent-bcc.lindsaar.net'
        message.resent_cc =     'mikel@resent-cc.lindsaar.net'
        message.resent_date =   '12 Aug 2009 00:00:03 GMT'
        message.resent_from =   'mikel@resent-from.lindsaar.net'
        message.resent_message_id = '<1234@resent_message_id.lindsaar.net>'
        message.resent_sender = 'mikel@resent-sender.lindsaar.net'
        message.resent_to =     'mikel@resent-to.lindsaar.net'
        message.sender =        'mikel@sender.lindsaar.net'
        message.subject =       'Hello there Mikel'
        message.to =            'mikel@to.lindsaar.net'
        message.content_type =  'text/plain; charset=UTF-8'
        message.content_transfer_encoding = '7bit'
        message.content_description =       'This is a test'
        message.content_id =                '<1234@message_id.lindsaar.net>'
        message.mime_version =  '1.0'
        message.body =          'This is a body of text'

        message.bcc.to_s.should           == 'mikel@bcc.lindsaar.net'
        message.cc.to_s.should            == 'mikel@cc.lindsaar.net'
        message.comments.to_s.should      == 'this is a comment'
        message.date.to_s.should          == '12 Aug 2009 00:00:01 GMT'
        message.from.to_s.should          == 'mikel@from.lindsaar.net'
        message.in_reply_to.to_s.should   == '<1234@in_reply_to.lindsaar.net>'
        message.keywords.to_s.should      == 'test, "of the new mail", system'
        message.message_id.to_s.should    == '<1234@message_id.lindsaar.net>'
        message.received.to_s.should      == '12 Aug 2009 00:00:02 GMT'
        message.references.to_s.should    == '<1234@references.lindsaar.net>'
        message.reply_to.to_s.should      == 'mikel@reply-to.lindsaar.net'
        message.resent_bcc.to_s.should    == 'mikel@resent-bcc.lindsaar.net'
        message.resent_cc.to_s.should     == 'mikel@resent-cc.lindsaar.net'
        message.resent_date.to_s.should   == '12 Aug 2009 00:00:03 GMT'
        message.resent_from.to_s.should   == 'mikel@resent-from.lindsaar.net'
        message.resent_message_id.to_s.should == '<1234@resent_message_id.lindsaar.net>'
        message.resent_sender.to_s.should == 'mikel@resent-sender.lindsaar.net'
        message.resent_to.to_s.should     == 'mikel@resent-to.lindsaar.net'
        message.sender.to_s.should        == 'mikel@sender.lindsaar.net'
        message.subject.to_s.should       == 'Hello there Mikel'
        message.to.to_s.should            == 'mikel@to.lindsaar.net'
        message.content_type.to_s.should              == 'text/plain; charset=UTF-8'
        message.content_transfer_encoding.to_s.should == '7bit'
        message.content_description.to_s.should       == 'This is a test'
        message.content_id.to_s.should                == '<1234@message_id.lindsaar.net>'
        message.mime_version.to_s.should              == '1.0'
        message.body.to_s.should          == 'This is a body of text'
      end
      
      it "should accept them in key, value form as symbols" do
        message = Mail.new
        message[:bcc] =           'mikel@bcc.lindsaar.net'
        message[:cc] =            'mikel@cc.lindsaar.net'
        message[:comments] =      'this is a comment'
        message[:date] =          '12 Aug 2009 00:00:01 GMT'
        message[:from] =          'mikel@from.lindsaar.net'
        message[:in_reply_to] =   '<1234@in_reply_to.lindsaar.net>'
        message[:keywords] =      'test, "of the new mail", system'
        message[:message_id] =    '<1234@message_id.lindsaar.net>'
        message[:received] =      '12 Aug 2009 00:00:02 GMT'
        message[:references] =    '<1234@references.lindsaar.net>'
        message[:reply_to] =      'mikel@reply-to.lindsaar.net'
        message[:resent_bcc] =    'mikel@resent-bcc.lindsaar.net'
        message[:resent_cc] =     'mikel@resent-cc.lindsaar.net'
        message[:resent_date] =   '12 Aug 2009 00:00:03 GMT'
        message[:resent_from] =   'mikel@resent-from.lindsaar.net'
        message[:resent_message_id] = '<1234@resent_message_id.lindsaar.net>'
        message[:resent_sender] = 'mikel@resent-sender.lindsaar.net'
        message[:resent_to] =     'mikel@resent-to.lindsaar.net'
        message[:sender] =        'mikel@sender.lindsaar.net'
        message[:subject] =       'Hello there Mikel'
        message[:to] =            'mikel@to.lindsaar.net'
        message[:content_type] =  'text/plain; charset=UTF-8'
        message[:content_transfer_encoding] = '7bit'
        message[:content_description] =       'This is a test'
        message[:content_id] =                '<1234@message_id.lindsaar.net>'
        message[:mime_version]=  '1.0'
        message[:body] =          'This is a body of text'
        
        message.bcc.to_s.should           == 'mikel@bcc.lindsaar.net'
        message.cc.to_s.should            == 'mikel@cc.lindsaar.net'
        message.comments.to_s.should      == 'this is a comment'
        message.date.to_s.should          == '12 Aug 2009 00:00:01 GMT'
        message.from.to_s.should          == 'mikel@from.lindsaar.net'
        message.in_reply_to.to_s.should   == '<1234@in_reply_to.lindsaar.net>'
        message.keywords.to_s.should      == 'test, "of the new mail", system'
        message.message_id.to_s.should    == '<1234@message_id.lindsaar.net>'
        message.received.to_s.should      == '12 Aug 2009 00:00:02 GMT'
        message.references.to_s.should    == '<1234@references.lindsaar.net>'
        message.reply_to.to_s.should      == 'mikel@reply-to.lindsaar.net'
        message.resent_bcc.to_s.should    == 'mikel@resent-bcc.lindsaar.net'
        message.resent_cc.to_s.should     == 'mikel@resent-cc.lindsaar.net'
        message.resent_date.to_s.should   == '12 Aug 2009 00:00:03 GMT'
        message.resent_from.to_s.should   == 'mikel@resent-from.lindsaar.net'
        message.resent_message_id.to_s.should == '<1234@resent_message_id.lindsaar.net>'
        message.resent_sender.to_s.should == 'mikel@resent-sender.lindsaar.net'
        message.resent_to.to_s.should     == 'mikel@resent-to.lindsaar.net'
        message.sender.to_s.should        == 'mikel@sender.lindsaar.net'
        message.subject.to_s.should       == 'Hello there Mikel'
        message.to.to_s.should            == 'mikel@to.lindsaar.net'
        message.content_type.to_s.should              == 'text/plain; charset=UTF-8'
        message.content_transfer_encoding.to_s.should == '7bit'
        message.content_description.to_s.should       == 'This is a test'
        message.content_id.to_s.should                == '<1234@message_id.lindsaar.net>'
        message.mime_version.to_s.should              == '1.0'
        message.body.to_s.should          == 'This is a body of text'
      end
      
      it "should accept them in key, value form as strings" do
        message = Mail.new
        message['bcc'] =           'mikel@bcc.lindsaar.net'
        message['cc'] =            'mikel@cc.lindsaar.net'
        message['comments'] =      'this is a comment'
        message['date'] =          '12 Aug 2009 00:00:01 GMT'
        message['from'] =          'mikel@from.lindsaar.net'
        message['in_reply_to'] =   '<1234@in_reply_to.lindsaar.net>'
        message['keywords'] =      'test, "of the new mail", system'
        message['message_id'] =    '<1234@message_id.lindsaar.net>'
        message['received'] =      '12 Aug 2009 00:00:02 GMT'
        message['references'] =    '<1234@references.lindsaar.net>'
        message['reply_to'] =      'mikel@reply-to.lindsaar.net'
        message['resent_bcc'] =    'mikel@resent-bcc.lindsaar.net'
        message['resent_cc'] =     'mikel@resent-cc.lindsaar.net'
        message['resent_date'] =   '12 Aug 2009 00:00:03 GMT'
        message['resent_from'] =   'mikel@resent-from.lindsaar.net'
        message['resent_message_id'] = '<1234@resent_message_id.lindsaar.net>'
        message['resent_sender'] = 'mikel@resent-sender.lindsaar.net'
        message['resent_to'] =     'mikel@resent-to.lindsaar.net'
        message['sender'] =        'mikel@sender.lindsaar.net'
        message['subject'] =       'Hello there Mikel'
        message['to'] =            'mikel@to.lindsaar.net'
        message['content_type'] =  'text/plain; charset=UTF-8'
        message['content_transfer_encoding'] = '7bit'
        message['content_description'] =       'This is a test'
        message['content_id'] =                '<1234@message_id.lindsaar.net>'
        message['mime_version'] =  '1.0'
        message['body'] =          'This is a body of text'
        
        message.bcc.to_s.should           == 'mikel@bcc.lindsaar.net'
        message.cc.to_s.should            == 'mikel@cc.lindsaar.net'
        message.comments.to_s.should      == 'this is a comment'
        message.date.to_s.should          == '12 Aug 2009 00:00:01 GMT'
        message.from.to_s.should          == 'mikel@from.lindsaar.net'
        message.in_reply_to.to_s.should   == '<1234@in_reply_to.lindsaar.net>'
        message.keywords.to_s.should      == 'test, "of the new mail", system'
        message.message_id.to_s.should    == '<1234@message_id.lindsaar.net>'
        message.received.to_s.should      == '12 Aug 2009 00:00:02 GMT'
        message.references.to_s.should    == '<1234@references.lindsaar.net>'
        message.reply_to.to_s.should      == 'mikel@reply-to.lindsaar.net'
        message.resent_bcc.to_s.should    == 'mikel@resent-bcc.lindsaar.net'
        message.resent_cc.to_s.should     == 'mikel@resent-cc.lindsaar.net'
        message.resent_date.to_s.should   == '12 Aug 2009 00:00:03 GMT'
        message.resent_from.to_s.should   == 'mikel@resent-from.lindsaar.net'
        message.resent_message_id.to_s.should == '<1234@resent_message_id.lindsaar.net>'
        message.resent_sender.to_s.should == 'mikel@resent-sender.lindsaar.net'
        message.resent_to.to_s.should     == 'mikel@resent-to.lindsaar.net'
        message.sender.to_s.should        == 'mikel@sender.lindsaar.net'
        message.subject.to_s.should       == 'Hello there Mikel'
        message.to.to_s.should            == 'mikel@to.lindsaar.net'
        message.content_type.to_s.should              == 'text/plain; charset=UTF-8'
        message.content_transfer_encoding.to_s.should == '7bit'
        message.content_description.to_s.should       == 'This is a test'
        message.content_id.to_s.should                == '<1234@message_id.lindsaar.net>'
        message.mime_version.to_s.should              == '1.0'
        message.body.to_s.should          == 'This is a body of text'
      end

    end
    
  end
  
  describe "MIME Emails" do
    
    describe "email generation" do
      
      describe "mime emails" do

        it "should read a mime version from an email" do
          mail = Mail.new("Mime-Version: 1.0")
          mail.mime_version.to_s.should == '1.0'
        end

        it "should return nil if the email has no mime version" do
          mail = Mail.new("To: bob")
          mail.mime_version.should == nil
        end

        it "should read the content-transfer-encoding" do
          mail = Mail.new("Content-Transfer-Encoding: quoted-printable")
          mail.content_transfer_encoding.to_s.should == 'quoted-printable'
        end

        it "should read the content-description" do
          mail = Mail.new("Content-Description: This is a description")
          mail.content_description.to_s.should == 'This is a description'
        end

        it "should return the content-type" do
          mail = Mail.new("Content-Type: text/plain")
          mail.message_content_type.should == 'text/plain'
        end

        it "should return the charset" do
          mail = Mail.new("Content-Type: text/plain; charset=utf-8")
          mail.charset.should == 'utf-8'
        end

        it "should return the main content-type" do
          mail = Mail.new("Content-Type: text/plain")
          mail.main_type.should == 'text'
        end

        it "should return the sub content-type" do
          mail = Mail.new("Content-Type: text/plain")
          mail.sub_type.should == 'plain'
        end

        it "should return the content-type parameters" do
          mail = Mail.new("Content-Type: text/plain; charset=US-ASCII; format=flowed")
          mail.mime_parameters.should == {'charset' => 'US-ASCII', 'format' => 'flowed'}
        end

        it "should recognize a multipart email" do
          mail = Mail.read(fixture('emails', 'mime_emails', 'multipart_email'))
          mail.should be_multipart
        end

        it "should recognize a non multipart email" do
          mail = Mail.read(fixture('emails', 'plain_emails', 'basic_email'))
          mail.should_not be_multipart
        end

        it "should give how may (top level) parts there are" do
          mail = Mail.read(fixture('emails', 'mime_emails', 'multipart_email'))
          mail.parts.length.should == 2
        end

        it "should give the content_type of each part" do
          mail = Mail.read(fixture('emails', 'mime_emails', 'multipart_email'))
          mail.message_content_type.should == 'multipart/mixed'
          mail.parts[0].message_content_type.should == 'text/plain'
          mail.parts[1].message_content_type.should == 'application/pdf'
        end

      end
      
      describe "multipart/alternative emails" do
        
        it "should know what it's boundary is if it is a multipart document" do
          mail = Mail.new('Content-Type: multitype/mixed; boundary="--==Boundary"')
          mail.boundary.should == "--==Boundary"
        end
        
        it "should return nil if there is no boundary defined" do
          mail = Mail.new('Content-Type: multitype/mixed')
          mail.boundary.should == nil
        end
        
        it "should return nil if there is no content-type defined" do
          mail = Mail.new
          mail.boundary.should == nil
        end
        
        it "should allow you to assign a text part" do
          mail = Mail.new
          text_mail = Mail.new("This is Text")
          doing { mail.text_part = text_mail }.should_not raise_error
        end
        
        it "should assign the text part and allow you to reference" do
          mail = Mail.new
          text_mail = Mail.new("This is Text")
          mail.text_part = text_mail
          mail.text_part.should == text_mail
        end
        
        it "should allow you to assign a html part" do
          mail = Mail.new
          html_mail = Mail.new("<b>This is HTML</b>")
          doing { mail.text_part = html_mail }.should_not raise_error
        end
        
        it "should assign the html part and allow you to reference" do
          mail = Mail.new
          html_mail = Mail.new("<b>This is HTML</b>")
          mail.html_part = html_mail
          mail.html_part.should == html_mail
        end

        it "should add the html part and text part" do
          mail = Mail.new
          mail.text_part = Mail::Part.new do
            body "This is Text"
          end
          mail.html_part = Mail::Part.new do
            content_type = "text/html; charset=US-ASCII"
            body = "<b>This is HTML</b>"
          end
          mail.parts.length.should == 2
          mail.parts.first.class.should == Mail::Part
          mail.parts.last.class.should == Mail::Part
        end
        
        it "should set a boundary when called with to_s" do
          mail = Mail.new
          mail.text_part = Mail::Part.new do
            body "This is Text"
          end
          mail.html_part = Mail::Part.new do
            content_type = "text/html; charset=US-ASCII"
            body "<b>This is HTML</b>"
          end
          mail.to_s
          mail.boundary.should =~ /--==_mimepart_[\w\d]+_[\w\d]+/
          mail.send(:boundary_line).should =~ /--==_mimepart_[\w\d]+_[\w\d]+/
        end
        
        it "should set the content type to multipart/alternative if you use the html_part and text_part helpers" do
          mail = Mail.new
          mail.text_part = Mail::Part.new do
            body "This is Text"
          end
          mail.html_part = Mail::Part.new do
            content_type = "text/html; charset=US-ASCII"
            body "<b>This is HTML</b>"
          end
          mail.to_s.should =~ %r|Content-Type: multipart/alternative;\s+boundary=#{mail.boundary}|
        end
        
        it "should add the end boundary tag" do
          mail = Mail.new
          mail.text_part = Mail::Part.new do
            body "This is Text"
          end
          mail.html_part = Mail::Part.new do
            content_type = "text/html; charset=US-ASCII"
            body "<b>This is HTML</b>"
          end
          mail.to_s.should =~ %r|#{mail.boundary}--|
        end
        
        it "should round trip a basic email" do
          mail = Mail.new('Subject: FooBar')
          mail.text_part = Mail::Part.new do
            body "This is Text"
          end
          mail.html_part = Mail::Part.new do
            content_type = "text/html; charset=US-ASCII"
            body "<b>This is HTML</b>"
          end
          parsed_mail = Mail.new(mail.to_s)
          parsed_mail.message_content_type.should == 'multipart/alternative'
          parsed_mail.boundary.should == mail.boundary
          parsed_mail.parts.length.should == 2
          parsed_mail.parts[0].body.to_s.should == "This is Text"
          parsed_mail.parts[1].body.to_s.should == "<b>This is HTML</b>"
        end

        it "should not put message-ids into parts" do
          mail = Mail.new('Subject: FooBar')
          mail.text_part = Mail::Part.new do
            body "This is Text"
          end
          mail.html_part = Mail::Part.new do
            content_type = "text/html; charset=US-ASCII"
            body "<b>This is HTML</b>"
          end
          mail.to_s
          mail.parts.first.message_id.should be_nil
          mail.parts.last.message_id.should be_nil
        end

      end

    end
    
  end
  
  describe "handling missing required fields:" do
    
    describe "every email" do
    
      describe "Message-ID" do
        it "should say if it has a message id" do
          mail = Mail.new do
               from 'mikel@test.lindsaar.net'
                 to 'you@test.lindsaar.net'
            subject 'This is a test email'
               body 'This is a body of the email'
          end
          mail.should_not be_has_message_id
        end

        it "should preserve any message id that you pass it if add_message_id is called explicitly" do
          mail = Mail.new do
               from 'mikel@test.lindsaar.net'
                 to 'you@test.lindsaar.net'
            subject 'This is a test email'
               body 'This is a body of the email'
          end
          mail.add_message_id("ThisIsANonUniqueMessageId")
          mail.to_s.should =~ /Message-ID: ThisIsANonUniqueMessageId\r\n/
        end

        it "should generate a random message ID if nothing is passed to add_message_id" do
          mail = Mail.new do
               from 'mikel@test.lindsaar.net'
                 to 'you@test.lindsaar.net'
            subject 'This is a test email'
               body 'This is a body of the email'
          end
          mail.add_message_id
          fqdn ||= ::Socket.gethostname
          mail.to_s.should =~ /Message-ID: <[\d\w_]+@#{fqdn}.mail>\r\n/
        end

        it "should make an email and inject a message ID if none was set if told to_s" do
          mail = Mail.new do
               from 'mikel@test.lindsaar.net'
                 to 'you@test.lindsaar.net'
            subject 'This is a test email'
               body 'This is a body of the email'
          end
          (mail.to_s =~ /Message-ID: <.+@.+.mail>/i).should_not be_nil      
        end

        it "should add the message id to the message permanently once sent to_s" do
          mail = Mail.new do
               from 'mikel@test.lindsaar.net'
                 to 'you@test.lindsaar.net'
            subject 'This is a test email'
               body 'This is a body of the email'
          end
          mail.to_s
          mail.should be_has_message_id
        end
      
        it "should add a body part if it is missing" do
          mail = Mail.new
          mail.to_s
          mail.body.class.should == Mail::Body
        end
      end

      describe "Date" do
        it "should say if it has a date" do
          mail = Mail.new do
               from 'mikel@test.lindsaar.net'
                 to 'you@test.lindsaar.net'
            subject 'This is a test email'
               body 'This is a body of the email'
          end
          mail.should_not be_has_date
        end

        it "should preserve any date that you pass it if add_date is called explicitly" do
          mail = Mail.new do
               from 'mikel@test.lindsaar.net'
                 to 'you@test.lindsaar.net'
            subject 'This is a test email'
               body 'This is a body of the email'
          end
          mail.add_date("Mon, 24 Nov 1997 14:22:01 -0800")
          mail.to_s.should =~ /Date: Mon, 24 Nov 1997 14:22:01 -0800/
        end

        it "should generate a current date if nothing is passed to add_date" do
          mail = Mail.new do
               from 'mikel@test.lindsaar.net'
                 to 'you@test.lindsaar.net'
            subject 'This is a test email'
               body 'This is a body of the email'
          end
          mail.add_date
          mail.to_s.should =~ /Date: \w{3}, [\s\d]\d \w{3} \d{4} \d{2}:\d{2}:\d{2} [-+]?\d{4}\r\n/
        end

        it "should make an email and inject a date if none was set if told to_s" do
          mail = Mail.new do
               from 'mikel@test.lindsaar.net'
                 to 'you@test.lindsaar.net'
            subject 'This is a test email'
               body 'This is a body of the email'
          end
          mail.to_s.should =~ /Date: \w{3}, [\s\d]\d \w{3} \d{4} \d{2}:\d{2}:\d{2} [-+]?\d{4}\r\n/
        end

        it "should add the date to the message permanently once sent to_s" do
          mail = Mail.new do
               from 'mikel@test.lindsaar.net'
                 to 'you@test.lindsaar.net'
            subject 'This is a test email'
               body 'This is a body of the email'
          end
          mail.to_s
          mail.should be_has_date
        end
      end

    end
    
    describe "mime emails" do
      
      describe "mime-version" do
        it "should say if it has a mime-version" do
          mail = Mail.new do
               from 'mikel@test.lindsaar.net'
                 to 'you@test.lindsaar.net'
            subject 'This is a test email'
               body 'This is a body of the email'
          end
          mail.should_not be_has_mime_version
        end

        it "should preserve any mime version that you pass it if add_mime_version is called explicitly" do
          mail = Mail.new do
               from 'mikel@test.lindsaar.net'
                 to 'you@test.lindsaar.net'
            subject 'This is a test email'
               body 'This is a body of the email'
          end
          mail.add_mime_version("3.0 (This is an unreal version number)")
          mail.to_s.should =~ /Mime-Version: 3.0 \(This is an unreal version number\)\r\n/
        end

        it "should generate a mime version if nothing is passed to add_date" do
          mail = Mail.new do
               from 'mikel@test.lindsaar.net'
                 to 'you@test.lindsaar.net'
            subject 'This is a test email'
               body 'This is a body of the email'
          end
          mail.add_mime_version
          mail.to_s.should =~ /Mime-Version: 1.0\r\n/
        end

        it "should make an email and inject a mime_version if none was set if told to_s" do
          mail = Mail.new do
               from 'mikel@test.lindsaar.net'
                 to 'you@test.lindsaar.net'
            subject 'This is a test email'
               body 'This is a body of the email'
          end
          mail.to_s.should =~ /Mime-Version: 1.0\r\n/
        end

        it "should add the mime version to the message permanently once sent to_s" do
          mail = Mail.new do
               from 'mikel@test.lindsaar.net'
                 to 'you@test.lindsaar.net'
            subject 'This is a test email'
               body 'This is a body of the email'
          end
          mail.to_s
          mail.should be_has_mime_version
        end
      end
      
      describe "content type" do
      
        it "should say if it has a content type" do
          mail = Mail.new('Content-Type: text/plain')
          mail.should be_has_content_type
        end

        it "should say if it does not have a content type" do
          mail = Mail.new
          mail.should_not be_has_content_type
        end

        it "should say if it has a charset" do
          mail = Mail.new('Content-Type: text/plain; charset=US-ASCII')
          mail.should be_has_charset
        end

        it "should say if it has a charset" do
          mail = Mail.new('Content-Type: text/plain')
          mail.should_not be_has_charset
        end

        it "should not raise a warning if there is no charset defined and only US-ASCII chars" do
          body = "This is plain text US-ASCII"
          mail = Mail.new
          mail.body = body
          STDERR.should_not_receive(:puts)
          mail.to_s 
        end

        it "should set the content type to text/plain; charset=us-ascii" do
          body = "This is plain text US-ASCII"
          mail = Mail.new
          mail.body = body
          mail.to_s =~ %r{Content-Type: text/plain; charset=US-ASCII}
        end

        it "should raise a warning if there is no content type and there is non ascii chars and default to text/plain, UTF-8" do
          body = "This is NOT plain text ASCII　− かきくけこ"
          mail = Mail.new
          mail.body = body
          mail.content_transfer_encoding = "8bit"
          STDERR.should_receive(:puts).with("Non US-ASCII detected and no charset defined.\nDefaulting to UTF-8, set your own if this is incorrect.")
          mail.to_s =~ %r{Content-Type: text/plain; charset=UTF-8}
        end

        it "should raise a warning if there is no charset parameter and there is non ascii chars and default to text/plain, UTF-8" do
          body = "This is NOT plain text ASCII　− かきくけこ"
          mail = Mail.new
          mail.body = body
          mail.content_type = "text/plain"
          mail.content_transfer_encoding = "8bit"
          STDERR.should_receive(:puts).with("Non US-ASCII detected and no charset defined.\nDefaulting to UTF-8, set your own if this is incorrect.")
          mail.to_s =~ %r{Content-Type: text/plain; charset=UTF-8}
        end

        it "should not raise a warning if there is a charset defined and there is non ascii chars" do
          body = "This is NOT plain text ASCII　− かきくけこ"
          mail = Mail.new
          mail.body = body
          mail.content_transfer_encoding = "8bit"
          mail.content_type = "text/plain; charset=UTF-8"
          STDERR.should_not_receive(:puts)
          mail.to_s 
        end
      
      end
      
      describe "content-transfer-encoding" do

        it "should not raise a warning if there is no content-transfer-encoding and only US-ASCII chars" do
          body = "This is plain text US-ASCII"
          mail = Mail.new
          mail.body = body
          STDERR.should_not_receive(:puts)
          mail.to_s 
        end

        it "should set the content-transfer-encoding to 7bit" do
          body = "This is plain text US-ASCII"
          mail = Mail.new
          mail.body = body
          mail.to_s =~ %r{Content-Transfer-Encoding: 7bit}
        end

        it "should raise a warning if there is no content-transfer-encoding and there is non ascii chars and default to 8bit" do
          body = "This is NOT plain text ASCII　− かきくけこ"
          mail = Mail.new
          mail.body = body
          mail.content_type = "text/plain; charset=utf-8"
          mail.should be_has_content_type
          mail.should be_has_charset
          STDERR.should_receive(:puts).with("Non US-ASCII detected and no content-transfer-encoding defined.\nDefaulting to 8bit, set your own if this is incorrect.")
          mail.to_s =~ %r{Content-Transfer-Encoding: 8bit}
        end

        it "should not raise a warning if there is a content-transfer-encoding defined and there is non ascii chars" do
          body = "This is NOT plain text ASCII　− かきくけこ"
          mail = Mail.new
          mail.body = body
          mail.content_type = "text/plain; charset=utf-8"
          mail.content_transfer_encoding = "8bit"
          STDERR.should_not_receive(:puts)
          mail.to_s 
        end

      end
      
    end
    
  end
  
  describe "output" do
    
    it "should make an email and allow you to call :to_s on it to get a string" do
      mail = Mail.new do
           from 'mikel@test.lindsaar.net'
             to 'you@test.lindsaar.net'
        subject 'This is a test email'
           body 'This is a body of the email'
      end
      
      mail.to_s.should =~ /From: mikel@test.lindsaar.net\r\n/
      mail.to_s.should =~ /To: you@test.lindsaar.net\r\n/
      mail.to_s.should =~ /Subject: This is a test email\r\n/
      mail.to_s.should =~ /This is a body of the email/

    end

  end
  
end
