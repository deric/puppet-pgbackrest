# frozen_string_literal: true

require 'spec_helper'

describe 'pgbackrest::instance_id' do
  it { is_expected.to run.with_params('psql01a.de').and_return(1) }
  it { is_expected.to run.with_params('psql01b.de').and_return(2) }
  it { is_expected.to run.with_params('psql02a.de').and_return(1) }
  it { is_expected.to run.with_params('psql01b.de.recombee.net').and_return(2) }
  it { is_expected.to run.with_params('psql01c').and_return(3) }
  it { is_expected.to run.with_params('PSQL01B').and_return(2) }

  # no member suffix: standalone server, treated as the first (primary) member
  it { is_expected.to run.with_params('psql01').and_return(1) }
  it { is_expected.to run.with_params('psql01.de').and_return(1) }

  # trailing letter without preceding digits is not a member suffix
  it { is_expected.to run.with_params('alpha').and_return(1) }

  it { is_expected.to run.with_params(nil).and_raise_error(StandardError) }
end
