require 'spec_helper'

describe User do
  it_behaves_like "commentables"

  let :attrs do
    {
      :name     => 'John Doe',
      :email    => 'test@example.com',
      :password => 'password',
    }
  end

  describe "user creation" do
    it "creates a user given valid attributes" do
      User.new(attrs).should be_valid
    end

    it "requires a name" do
      User.new(attrs.merge(:name => '')).should_not be_valid
    end

    it "rejects a name that is too short" do
      User.new(attrs.merge(:name => 'a')).should_not be_valid
    end

    it "rejects a name that is too long" do
      User.new(attrs.merge(:name => 'a' * 100)).should_not be_valid
    end

    it "rejects an invalid email address" do
      User.new(attrs.merge(:email => 'invalid_email')).should_not be_valid
    end

    it "rejects duplicate email addresses" do
      User.create!(attrs)
      User.new(attrs).should_not be_valid
    end
  end

  describe "user persistence" do
    it "normalises the email address" do
      user = User.new(attrs.merge(:email => 'TESTme@EXAMPLE.com'))
      user.save(:validate => false)

      user.email.should == 'testme@example.com'
    end
  end

  describe "password validation" do
    def test_user_password(password, password_confirmation = nil)
      User.new(attrs.merge(
        :password              => password,
        :password_confirmation => (password || password_confirmation)
      )).should_not be_valid
    end

    it "requires a password" do
      test_user_password('')
    end

    it "requires a matching password confirmation" do
      test_user_password('a', 'b')
    end

    it "rejects a password that is too short" do
      test_user_password('a')
    end

    it "rejects a password that is too long" do
      test_user_password('a' * 50)
    end
  end

  context "user functions and associations" do
    subject { User.new }

    describe "user permissions" do
      it "responds to is_xxx?" do
        subject.respond_to?(:is_admin?).should be_true
        subject.respond_to?(:is_entrepreneur?).should be_true
        subject.respond_to?(:is_investor?).should be_true
      end
    end

    describe "user groups" do
      it "responds to startups" do
        subject.association(:startups).should be_a(ActiveRecord::Associations::HasManyThroughAssociation)
      end

      it "responds to investors" do
        subject.association(:investor).should be_a(ActiveRecord::Associations::HasOneAssociation)
      end

      it "responds to 'is_entrepreneur?'" do
        subject.is_entrepreneur?.should == false
      end

      it "responds to 'is_investor?'" do
        subject.is_investor?.should == false
      end

      it "adds startups" do
        subject.startups << Startup.new
        subject.is_entrepreneur?.should == true
      end

      it "adds investors" do
        subject.investor = Investor.new
        subject.is_investor?.should == true
      end
    end

    context "related resources" do
      subject       { User.make! }
      let(:user)    { User.make! }
      let(:user2)   { User.make! }
      let(:startup) { Startup.make! }

      describe "user followers" do
        it_behaves_like "followables"

        it "has followings" do
          subject.respond_to?(:followed).should be_true
        end

        describe "followed targets" do
          it "counts the number of followed targets" do
            subject.users_followed.count.should == 0
            subject.startups_followed.count.should == 0

            subject.follow(user)
            subject.users_followed.count.should == 1
            subject.startups_followed.count.should == 0

            subject.follow(startup)
            subject.users_followed.count.should == 1
            subject.startups_followed.count.should == 1

            subject.unfollow(user)
            subject.users_followed.count.should == 0
            subject.startups_followed.count.should == 1

            subject.unfollow(startup)
            subject.users_followed.count.should == 0
            subject.startups_followed.count.should == 0
          end
        end

        describe "followed micro posts" do
          it "sees micro posts from followed users, including self" do
            subject.follow(user)
            subject.follow(user2)

            time_travel_to(3.minute.ago) { user.add_micro_post('Hello world!') }
            time_travel_to(2.minute.ago) { user.add_micro_post('Hello ruby!') }
            time_travel_to(1.minute.ago) { user2.add_micro_post('Hello from user2!') }

            subject.add_micro_post('Hello from myself!')

            subject.followed_micro_posts.first.content.should == 'Hello from myself!'
            subject.followed_micro_posts.last.content.should == 'Hello world!'

            subject.followed_micro_posts.count.should == 4

            subject.unfollow(user)
            subject.followed_micro_posts.count.should == 2

            subject.unfollow(user2)
            subject.followed_micro_posts.count.should == 1
          end
        end
      end
    end
  end
end
