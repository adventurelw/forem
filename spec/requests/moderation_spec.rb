require 'spec_helper'

describe "moderation" do
  let(:forum) { FactoryGirl.create(:forum) }
  let(:user) { FactoryGirl.create(:user) }

  context "as a new user" do
    before do
      sign_in(user)
    end

    it "has their first topic moderated" do
      visit new_forum_topic_path(forum)
      fill_in "Subject", :with => "FIRST TOPIC"
      fill_in "Text", :with => "User's first words"
      click_button "Create Topic"

      flash_notice!("This topic has been created.")
      assert_seen("This topic is currently pending review. Only the user who created it and moderators can view it.", :within => :topic_moderation)
    end


    it "has their first post moderated" do
      topic = Factory(:topic, :forum => forum)
      topic.approve!
      visit forum_topic_path(forum, topic)

      click_link "Reply"
      fill_in "Text", :with => "I am replying to a topic."
      click_button "Reply"

      flash_notice!("Your reply has been posted.")
      assert_seen("This post is currently pending review. Only the user who posted it and moderators can view it.", :within => :post_moderation)
    end

    it "cannot see the moderation tools" do
      visit forum_path(forum)
      page.should_not have_content("Moderation Tools")
    end

    it "cannot see a unapproved topic by another user" do
      topic = Factory(:topic, :forum => forum, :subject => "In review")
      visit forum_path(forum)
      page.should_not have_content("In review")

      visit forum_topic_path(forum, topic)
      flash_alert!("The topic you are looking for could not be found.")
    end

    it "cannot see an unapproved posts by another user" do
      topic = Factory(:topic, :forum => forum)
      post = Factory(:post, :topic => topic, :text => "BUY VIAGRA")
      topic.approve!

      visit forum_topic_path(forum, topic)
      page.should_not have_content("BUY VIAGRA")
    end

    context "approved users" do
      before do
        User.any_instance.stub(:forem_state).and_return("approved")
      end

      it "subsequent topics bypass the moderation queue" do
        visit new_forum_topic_path(forum)
        fill_in "Subject", :with => "SECOND TOPIC"
        fill_in "Text", :with => "User's second words"
        click_button "Create Topic"
        flash_notice!("This topic has been created.")
        page.should_not have_content("This topic is currently pending review.")
      end

      it "subsequent posts bypass the moderation queue" do
        topic = Factory(:approved_topic, :forum => forum)
        visit forum_topic_path(forum, topic)
        click_link "Reply"
        fill_in "Text", :with => "Freedom!!"
        click_button "Reply"
        flash_notice!("Your reply has been posted.")
        page.should_not have_content("This post is currently pending review.")
      end
    end

    context "spam users" do
      before do
        User.any_instance.stub(:forem_state).and_return("spam")
      end

      it "cannot start a new topic" do
        visit forum_path(forum)
        click_link "New topic"
        flash_alert!("Your account has been flagged for spam. You cannot create a new topic at this time.")
      end

      it "cannot reply to a topic" do
        topic = Factory(:approved_topic, :forum => forum)
        visit forum_topic_path(forum, topic)
        click_link "Reply"
        flash_alert!("Your account has been flagged for spam. You cannot create a new post at this time.")
      end
    end

  end

  context "moderators" do
    let!(:moderator) { Factory(:user, :login => "moderator") }
    let!(:group) do
      group = Factory(:group)
      group.members << moderator
      group.save!
      group
    end

    let!(:forum) { Factory(:forum) }
    let!(:topic) { Factory(:topic, :forum => forum) }
    let!(:post) { Factory(:post, :topic => topic) }

    before do
      forum.moderators << group
      sign_in(moderator)
      topic.approve!
    end

    context "mass moderation" do
      it "can approve a post by a new user" do

        visit forum_path(forum)
        click_link "Moderation Tools"

        choose "Approve"
        click_button "Moderate"

        flash_notice!("The selected posts have been moderated.")
        post.reload
        post.should be_approved
        post.user.reload.forem_state.should == "approved"
      end

      it "can mark a post as spam" do
        visit forum_path(forum)
        click_link "Moderation Tools"

        choose "Spam"
        click_button "Moderate"
        flash_notice!("The selected posts have been moderated.")
        post.reload
        post.should be_spam
        post.user.reload.forem_state.should == "spam"
      end
    end

    context "singular moderation" do
      it "can approve a post by a new user" do
        visit forum_topic_path(forum, topic)
        choose "Approve"
        click_button "Moderate"

        flash_notice!("The selected posts have been moderated.")
        post.user.reload.forem_state.should == "approved"
      end
    end
  end
end
