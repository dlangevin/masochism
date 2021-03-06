require File.dirname(__FILE__) + '/../../../../config/environment'
require 'test/unit'
require 'fileutils'
require 'pp'

module ActiveReload
  class ConnectionProxyTest < Test::Unit::TestCase

    MASTER = '/tmp/db/masochism_master.sqlite3'
    SLAVE = '/tmp/db/masochism_slave.sqlite3'

    def teardown
      ActiveRecord::Base.remove_connection
      FileUtils.rm_f(MASTER)
      FileUtils.rm_f(SLAVE)
    end

    def test_slave_defined_returns_false_when_slave_not_defined
      ActiveRecord::Base.configurations = default_config
      assert_nil ActiveReload::ConnectionProxy.slave_defined?, 'Slave should not be defined'
    end
    
    def test_slave_defined_returns_true_when_slave_defined
      ActiveRecord::Base.configurations = slave_inside_config
      assert_not_nil ActiveReload::ConnectionProxy.slave_defined?, 'Slave should be defined'
    end
    
    def test_default
      ActiveRecord::Base.configurations = default_config
      reload
      ActiveReload::ConnectionProxy.setup!
    
      ActiveRecord::Base.connection.master.execute('CREATE TABLE foo (id int)')
      assert_equal ['foo'], ActiveRecord::Base.connection.tables, 'Master and Slave should be the same database'
      assert_equal ['foo'], ActiveRecord::Base.connection.slave.tables, 'Master and Slave should be the same database'
    end
    
    def test_master_database_outside_environment
      ActiveRecord::Base.configurations = master_outside_config
      reload
      ActiveReload::ConnectionProxy.setup!
    
      ActiveRecord::Base.connection.master.execute('CREATE TABLE foo (id int)')
      assert_equal [], ActiveRecord::Base.connection.tables, 'Master and Slave should be different databases'
      assert_equal [], ActiveRecord::Base.connection.slave.tables, 'Master and Slave should be different databases'
    end
    
    def test_master_database_within_environment
      ActiveRecord::Base.configurations = master_inside_config
      reload
      ActiveReload::ConnectionProxy.setup!
    
      ActiveRecord::Base.connection.master.execute('CREATE TABLE foo (id int)')
      assert_equal [], ActiveRecord::Base.connection.tables, 'Master and Slave should be different databases'
      assert_equal [], ActiveRecord::Base.connection.slave.tables, 'Master and Slave should be different databases'
    end
    
    def test_slave_database_within_environment
      ActiveRecord::Base.configurations = slave_inside_config
      reload
      ActiveReload::ConnectionProxy.setup!
    
      ActiveRecord::Base.connection.master.execute('CREATE TABLE foo (id int)')
      assert_equal [], ActiveRecord::Base.connection.tables, 'Master and Slave should be different databases'
      assert_equal [], ActiveRecord::Base.connection.slave.tables, 'Master and Slave should be different databases'
    
    end
    
    def test_with_master_uses_master
      ActiveRecord::Base.configurations = slave_inside_config
      reload
      ActiveReload::ConnectionProxy.setup!
      
      ActiveRecord::Base.connection.master.execute('CREATE TABLE foo (id int)')
      ActiveRecord::Base.connection.with_master do
        assert_equal ['foo'], ActiveRecord::Base.connection.tables, 'Should use the master db inside the with_master block'
        assert_equal [], ActiveRecord::Base.connection.slave.tables, 'Master and Slave should be different databases'
      end
    end
    
    def test_delegates_methods_to_master
      ActiveRecord::Base.configurations = slave_inside_config
      reload
      ActiveReload::ConnectionProxy.setup!
      
      ActiveRecord::Base.connection.execute('CREATE TABLE foo (id int)')
      assert_equal ['foo'], ActiveRecord::Base.connection.master.tables, 'Master should be used for create table'
      
    end
    
    def test_nested_with_master_really_uses_with_master
      ActiveRecord::Base.configurations = slave_inside_config
      reload
      ActiveReload::ConnectionProxy.setup!
      
      conn = ActiveRecord::Base.connection
      conn.with_master do
        conn.with_master do
          assert_equal conn.current, conn.master, "Connection should be master"
        end
        assert_equal conn.current, conn.master, "Connection should be master"
      end
      assert_equal conn.current, conn.slave, "Connection should be slave"
      
    end

  private

    def reload
      # force establish_connection calls to be re-executed
      load File.dirname(__FILE__)+'/../lib/active_reload/connection_proxy.rb'
    end

    def default_config
      {Rails.env => {'adapter' => 'sqlite3', 'database' => MASTER}}
    end

    def master_outside_config
      {
        Rails.env => {'adapter' => 'sqlite3', 'database' => SLAVE},
        'master_database' => {'adapter' => 'sqlite3', 'database' => MASTER}
      }
    end

    def master_inside_config
      {
        Rails.env => {
          'adapter' => 'sqlite3', 
          'database' => SLAVE,
          'master_database' => {
            'adapter' => 'sqlite3', 
            'database' => MASTER
          }
        }
      }
    end

    def slave_inside_config
      {
        Rails.env => {
          'adapter' => 'sqlite3', 
          'database' => MASTER,
          'slave_database' => {
            'adapter' => 'sqlite3', 
            'database' => SLAVE
          }
        }
      }
    end


  end # class ConnectionProxyTest
end # module ActiveReload
