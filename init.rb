require File.dirname(__FILE__) + '/lib/fast_sessions'

ActiveRecord::SessionStore.session_class = ActiveRecord::SessionStore::FastSessions
