require File.dirname(__FILE__) + '/spec_helper'
require 'fast_sessions'

describe "ActiveRecord::SessionStore::FastSessions Class" do
  it "should have table_name attribute" do
    ActiveRecord::SessionStore::FastSessions.table_name = "table_name"
    ActiveRecord::SessionStore::FastSessions.table_name.should == "table_name"
  end

  it "should correctly marshal/unmarshal data" do
    data = [ "some", { :test => 'data', :structure => 1}, "to", :check, 'serializat', 10, "n" ]
    marshaled_data = ActiveRecord::SessionStore::FastSessions.marshal(data)
    marshaled_data.should_not be(nil)
    ActiveRecord::SessionStore::FastSessions.unmarshal(marshaled_data).should == data
  end
  
  it "should load data column size limit" do
    ActiveRecord::SessionStore::FastSessions.data_size_limit.should == 65535
  end
end

describe "FastSessions Class find_by_session_id() method" do
  before(:each) do
    @connection = mock("connection")
    @connection.stub!(:quote).and_return("something")
    @connection_pool = mock("connection_pool")
    @connection_pool.stub!(:with_connection).and_yield(@connection)
    ActiveRecord::Base.stub!(:connection_pool).and_return(@connection_pool)
    ActiveRecord::SessionStore::FastSessions.fallback_to_old_table = false

    @data = { :test => "value" }
    @marshaled_data = ActiveRecord::SessionStore::FastSessions.marshal(@data)
  end

  it "should return a ActiveRecord::SessionStore::FastSessions object with saved data when called for existing session" do
    @connection.should_receive(:select_one).and_return({'data' => @marshaled_data})
    session = ActiveRecord::SessionStore::FastSessions.find_by_session_id("test_id")
    session.class.should be(ActiveRecord::SessionStore::FastSessions)
    session.data.should == @data
  end

  it "should return a ActiveRecord::SessionStore::FastSessions object with empty hash when called for non-existing session" do
    @connection.should_receive(:select_one).and_return(nil)
    session = ActiveRecord::SessionStore::FastSessions.find_by_session_id("test_id")
    session.class.should be(ActiveRecord::SessionStore::FastSessions)
    session.data.should be_empty
  end

  it "should fallback to the old sessions table if session was not found in new one" do
    @connection.should_receive(:select_one).twice.and_return(nil, {'data' => @marshaled_data})
    ActiveRecord::SessionStore::FastSessions.fallback_to_old_table = true

    session = ActiveRecord::SessionStore::FastSessions.find_by_session_id("test_id")
    session.class.should be(ActiveRecord::SessionStore::FastSessions)
    session.data.should == @data
  end
end

describe "FastSessions object save() method" do
  before(:each) do
    @data = { :test => "value" }
    @marshaled_data = ActiveRecord::SessionStore::FastSessions.marshal(@data)

    @connection = mock("connection")
    @connection.stub!(:quote).and_return("something")
    @connection.should_receive(:select_one).and_return({'data' => @marshaled_data})
    @connection_pool = mock("connection_pool")
    @connection_pool.stub!(:with_connection).and_yield(@connection)
    ActiveRecord::Base.stub!(:connection_pool).and_return(@connection_pool)
    ActiveRecord::SessionStore::FastSessions.fallback_to_old_table = false

    @session = ActiveRecord::SessionStore::FastSessions.find_by_session_id("test_id")
  end

  it "should not save data if should_save_session? returns false" do
    @session.should_receive(:should_save_session?).and_return(false)
    @connection.should_not_receive(:update)
    @session.save
  end

  it "should save data if should_save_session? returns true" do
    @session.should_receive(:should_save_session?).and_return(true)
    @connection.should_receive(:update)
    @session.save
  end

  it "should not save data if it was not changed" do
    @connection.should_not_receive(:update)
    @session.save
  end

  it "should save data if it was changed" do
    @connection.should_receive(:update)
    @session.data[:ping] = "pong"
    @session.save
  end

  it "should not save data if it was changed, but user requested to skip saving" do
    @connection.should_not_receive(:update)
    @session.data[:ping] = "pong"
    @session.data[:skip_session_saving] = true
    @session.save
  end

  it "should delete :skip_session_saving and :force_session_saving from data hash" do
    @connection.should_receive(:update)
    @session.data[:skip_session_saving].should be_nil
    @session.data[:foce_session_saving].should be_nil

    @session.data[:skip_session_saving] = true
    @session.data[:force_session_saving] = true
    @session.save

    @session.data[:skip_session_saving].should be_nil
    @session.data[:foce_session_saving].should be_nil
  end

  it "should save data if it was changed and user requested to force saving" do
    @connection.should_receive(:update)
    @session.data[:ping] = "pong"
    @session.data[:force_session_saving] = true
    @session.save
  end

  it "should save data if it was not changed, but user requested to force saving" do
    @connection.should_receive(:update)
    @session.data[:force_session_saving] = true
    @session.save
  end

  it "should save data skip and force saving were requested (force has higher priority)" do
    @connection.should_receive(:update)
    @session.data[:skip_session_saving] = true
    @session.data[:force_session_saving] = true
    @session.save
  end

end

describe "FastSessions object save() method in special cases" do
  before(:each) do
    @data = { :test => "value" }
    @marshaled_data = ActiveRecord::SessionStore::FastSessions.marshal(@data)

    @connection = mock("connection")
    @connection.stub!(:quote).and_return("something")
    @connection_pool = mock("connection_pool")
    @connection_pool.stub!(:with_connection).and_yield(@connection)
    ActiveRecord::Base.stub!(:connection_pool).and_return(@connection_pool)
    ActiveRecord::SessionStore::FastSessions.fallback_to_old_table = false
  end

  it "should not save data if the only thing added to an empty session was a blank flash message" do
    @connection.should_receive(:select_one).and_return(nil)
    @session = ActiveRecord::SessionStore::FastSessions.find_by_session_id("another_id")

    @connection.should_not_receive(:update)
    @session.data["flash"] = {}
    @session.save
  end
  
  it "should raise ActionController::SessionOverflowError when data size exceeds data_size_limit" do
    @data = { :test => "value" * ActiveRecord::SessionStore::FastSessions.data_size_limit }
    @session = ActiveRecord::SessionStore::FastSessions.new(:session_id => 1222, :data => @data)
    lambda {@session.save}.should raise_error(ActionController::SessionOverflowError)
  end
end
