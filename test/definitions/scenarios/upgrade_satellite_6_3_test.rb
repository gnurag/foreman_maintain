require 'test_helper'

module Scenarios
  describe Satellite_6_3::PreUpgradeCheck do
    include DefinitionsTestHelper

    before do
      assume_feature_present(:downstream) do |feature|
        feature.any_instance.stubs(:current_version => version('6.2.11'))
      end
      assume_feature_present(:foreman_tasks)
    end

    let :scenario do
      assert_scenario(:tags => [:pre_upgrade_checks, :upgrade_to_satellite_6_3])
    end

    it 'is valid for 6.2.0 and 6.2.z version' do
      assert_scenario(:tags => [:pre_upgrade_checks, :upgrade_to_satellite_6_3])

      assume_feature_present(:downstream) do |feature_class|
        feature_class.any_instance.stubs(:current_version => version('6.2.0'))
      end
      detector.refresh
      assert_scenario(:tags => [:pre_upgrade_checks, :upgrade_to_satellite_6_3])

      assume_feature_present(:downstream) do |feature_class|
        feature_class.any_instance.stubs(:current_version => version('6.2.1'))
      end
      detector.refresh
      assert_scenario(:tags => [:pre_upgrade_checks, :upgrade_to_satellite_6_3])
    end

    it 'is valid only for 6.2.z versions' do
      assert_scenario(:tags => [:pre_upgrade_checks, :upgrade_to_satellite_6_3])

      assume_feature_present(:downstream) do |feature_class|
        feature_class.any_instance.stubs(:current_version => version('6.1.9'))
      end
      detector.refresh
      refute_scenario(:tags => [:pre_upgrade_checks, :upgrade_to_satellite_6_3])

      assume_feature_present(:downstream) do |feature_class|
        feature_class.any_instance.stubs(:current_version => version('6.3.1'))
      end
      detector.refresh
      refute_scenario(:tags => [:pre_upgrade_checks, :upgrade_to_satellite_6_3])

      assume_feature_absent(:downstream)
      detector.refresh
      refute_scenario(:tags => [:pre_upgrade_checks, :upgrade_to_satellite_6_3])
    end

    it 'composes the pre upgrade checks for migration from satellite 6.2.z to 6.3' do
      assert(scenario.steps.find { |step| step.is_a? Checks::ForemanTasks::Invalid::CheckOld })
    end
  end
end
