require File.join(File.dirname(__FILE__), %w[spec_helper])

require 'active_model'

class Post
  extend ActiveModel::Callbacks

  define_model_callbacks :create
  attr_accessor :id, :to_param, :creator_id, :name

  include Timeline::Target
  include Timeline::Track
  track :new_post

  def initialize(options={})
    @creator_id = options.delete :creator_id
    @name = options.delete :name
  end

  def save
    run_callbacks :create
    true
  end

  def creator
    User.find(creator_id)
  end

  def to_s
    name
  end
  
  
  class << self
    def find post_id
      Post.new(id: post_id)
    end
  end
  
  
end




class Comment
  extend ActiveModel::Callbacks

  define_model_callbacks :create
  attr_accessor :id, :creator_id, :body, :post_id

  include Timeline::Track

  track :new_comment, object: [:post_name, :post_id, :body], target: :post, mentionable: :body

  def initialize(options={})
    @creator_id = options.delete :creator_id
    @body = options.delete :body
  end

  def save
    run_callbacks :create
    true
  end

  
  def post
    Post.find(post_id)
  end
  
  def post_name
    post.name
  end

  def creator
    User.find(creator_id)
  end

  def to_s
    "Comment"
  end
  
  
  
end



class User
  include Timeline::Actor
  attr_accessor :id, :to_param, :username

  def initialize(options={})
    @id = options.delete :id
    @username = options.delete :username
  end

  class << self
    def find user_id
      User.new(id: user_id)
    end

    def find_by_username username
      User.new(username: username)
    end
  end
end





describe Timeline::Track do
  let(:creator) { User.new(id: 1, username: "first_user") }
  let(:post) { Post.new(creator_id: creator.id, name: "New post") }
  let(:comment) { Comment.new(creator_id: creator.id, id: 1, post_id: post.id) }

  describe "included in an ActiveModel-compliant class" do
    it "tracks on create by default" do
      post.should_receive(:track_new_post_after_create)
      post.save
    end

    it "uses the creator as the actor by default" do
      post.should_receive(:creator).and_return(mock("User", id: 1, to_param: "1", followers: []))
      post.save
    end

    it "adds the activity to the global timeline set" do
      post.save
      creator.timeline(:global).last.should be_kind_of(Timeline::Activity)
    end

    it "adds the activity to the actor's timeline" do
      post.save
      creator.timeline.last.should be_kind_of(Timeline::Activity)
    end

    it "cc's the actor's followers by default" do
      follower = User.new(id: 2)
      User.any_instance.should_receive(:followers).and_return([follower])
      post.save
      follower.timeline.last.verb.should == "new_post"
      follower.timeline.last.actor.id.should == 1
    end
    
    it "adds the activity to the target's timeline" do
      comment.save
      comment.post.id.should == post.id
      post.activities.last.should be_kind_of(Timeline::Activity)
    end
    
    
    
  end

  describe "with extra_fields" do
    it "stores the extra fields in the timeline" do
      comment.save
      creator.timeline.first.object.should respond_to :post_id
    end
  end

  describe "tracking mentions" do
    it "adds to a user's mentions timeline" do
      User.stub(:find_by_username).and_return(creator)
      Comment.new(creator_id: creator.id, body: "@first_user should see this").save
      creator.timeline(:mentions).first.object.body.should == "@first_user should see this"
    end
  end
end
