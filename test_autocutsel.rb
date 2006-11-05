require 'test/unit'

class AutoCutSelTest < Test::Unit::TestCase
  def get_selection selection = nil
    command = "./cutsel sel"
    command << " -s #{selection}" if selection
    result = %x(#{command}).chomp
    result = nil if result == "Nobody owns the selection"
    result
  end
  
  def get_buffer
    %x(./cutsel cut).chomp
  end
  
  def set_buffer value
    system "./cutsel", "cut", value
  end
  
  def set_selection value, selection = nil
    command = ["./cutsel", "sel", value]
    command += ["-s", selection] if selection
    pid = Process.fork {
      exec *command
    }
    sleep 0.1
    begin
      yield
    ensure
      Process.kill("TERM", pid) rescue
      sleep 0.1
      Process.kill("KILL", pid) rescue
      Process.waitpid pid
    end
  end
  
  def run_autocutsel options = {}
    command = ["./autocutsel", "-pause", "1"]
    command += ["-s", options[:selection]] if options[:selection]
    pid = Process.fork {
      exec *command
    }
    sleep 0.1
    begin
      yield
    ensure
      Process.kill("TERM", pid) rescue
      sleep 0.1
      Process.kill("KILL", pid) rescue
      Process.waitpid pid
    end
  end

  def run_autocutsel_and_make_it_own_selection value = "baz", selection = nil
    set_buffer "foo"
    set_selection "bar", selection do
      run_autocutsel :selection => selection do
        set_buffer value
        sleep 0.1
        yield
      end
    end
  end
  
  def get_targets
    %x(./cutsel targets).split("\n")[1..-1]
  end


  def test_cutsel_changes_buffer
    set_buffer "cutbuffer value"
    assert_equal "cutbuffer value", get_buffer
  end
  
  def test_cutsel_owns_selection
    set_selection "selection value" do
      assert_equal "selection value", get_selection
    end
    assert_nil get_selection
  end
  
  def test_autocutsel_changes_buffer
    set_buffer "foo"
    run_autocutsel do
      set_selection "bar" do
        sleep 0.1
      end
      assert_equal "bar", get_buffer
    end
    assert_equal "bar", get_buffer
    assert_nil get_selection
  end
  
  def test_autocutsel_owns_selection
    run_autocutsel_and_make_it_own_selection "my value" do
      assert_equal "my value", get_selection
    end
  end
  
  def test_autocutsel_targets
    run_autocutsel_and_make_it_own_selection do
      targets = get_targets
      %w( STRING LENGTH ).each do |target|
        assert targets.include?(target), "Target #{target.inspect} not provided in #{targets.inspect}"
      end
    end
  end
  
  def test_default_selection
    run_autocutsel_and_make_it_own_selection @method_name do
      assert_equal @method_name, get_selection("CLIPBOARD")
      assert_nil get_selection("my_selection")
    end
  end
  
  def test_primary_selection
    clipboard_value = get_selection("CLIPBOARD")
    run_autocutsel_and_make_it_own_selection @method_name, "PRIMARY" do
      assert_equal @method_name, get_selection("PRIMARY")
      assert_equal clipboard_value, get_selection("CLIPBOARD")
    end
  end
end