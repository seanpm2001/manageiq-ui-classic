describe ApplicationController do
  describe "#get_tagdata" do
    let(:record) { double("Host") }
    let(:user) { FactoryBot.create(:user, :userid => "testuser") }

    before do
      login_as user
      allow(record).to receive(:tagged_with).with(:cat => user.userid).and_return("my tags")
      allow(Classification).to receive(:find_assigned_entries).with(record).and_return(classifications)
    end

    context "when classifications exist" do
      let(:parent) { double("Parent", :description => "Department") }
      let(:child1) { double("Child1", :parent => parent, :description => "Automotive") }
      let(:child2) { double("Child2", :parent => parent, :description => "Financial Services") }
      let(:classifications) { [child1, child2] }

      it "populates the assigned filters in the session" do
        controller.send(:get_tagdata, record)
        expect(session[:assigned_filters]['Department']).to eq(["Automotive", "Financial Services"])
        expect(session[:mytags]).to eq("my tags")
      end
    end

    context "when classifications do not exist" do
      let(:classifications) { [] }

      it "sets the assigned filters to an empty hash in the session" do
        controller.send(:get_tagdata, record)
        expect(session[:assigned_filters]).to eq({})
        expect(session[:mytags]).to eq("my tags")
      end
    end
  end

  context "tag_edit_build_screen" do
    def add_entry(cat, options)
      raise "entries can only be added to classifications" unless cat.category?
      # Inherit from parent classification
      options.merge!(:read_only    => cat.read_only,
                     :syntax       => cat.syntax,
                     :single_value => cat.single_value,
                     :ns           => cat.ns)
      options[:parent_id] = cat.id # Ugly way to set up a child
      FactoryBot.create(:classification, options)
    end

    # creating record in different region
    def update_record_region(record)
      record.update_column(:id, record.id + MiqRegion.rails_sequence_factor)
    end

    # convert record id into region id
    def convert_to_region_id(id)
      MiqRegion.id_to_region(id)
    end

    before do
      # setup classification/entries with same name in different regions
      clergy = FactoryBot.create(:classification)
      add_entry(clergy, :name => "bishop", :description => "Bishop")

      # add another classification with different description,
      # then change description to be same as above after updating region id of record
      clergy2 = FactoryBot.create(:classification)
      update_record_region(clergy2)
      clergy2.update_column(:description, "Clergy")

      clergy_bishop2 = add_entry(clergy2, :name => "bishop", :description => "Bishop")
      update_record_region(clergy_bishop2)

      allow(Classification).to receive(:my_region_number).and_return(convert_to_region_id(clergy_bishop2.id))
      @st = FactoryBot.create(:service_template)
    end

    it "region id of classification/entries should match" do
      # only classification/entries from same region should be returned
      allow(controller).to receive(:button_url).with("application", @st.id, "save").and_return("save_url")
      allow(controller).to receive(:button_url).with("application", @st.id, "cancel").and_return("cancel_url")
      controller.instance_variable_set(:@edit, :new => {})
      controller.instance_variable_set(:@sb, {})
      controller.instance_variable_set(:@tagging, 'ServiceTemplate')
      controller.instance_variable_set(:@object_ids, [@st.id])
      session[:assigned_filters] = {:Test => %w("Entry1 Entry2)}

      controller.send(:tag_edit_build_screen)
      expect(convert_to_region_id(assigns(:tags)[:tags].first[:id]))
        .to eq(convert_to_region_id(assigns(:tags)[:tags].first[:values].first[:id]))
    end
  end

  describe '#tagging_edit' do
    let(:params) { nil }
    let(:s) { nil }

    before do
      allow(controller).to receive(:assert_privileges)
      allow(controller).to receive(:session).and_return(s)

      controller.params = params
    end

    context 'resetting changes' do
      let(:params) { {:button => "reset"} }
      let(:s) { {:tag_db => VmOrTemplate} }

      before do
        allow(controller).to receive(:tagging_edit_tags_reset)
      end

      it 'sets @tagging properly' do
        controller.send(:tagging_edit)
        expect(controller.instance_variable_get(:@tagging)).not_to be_nil
      end
    end

    # I CHALLENGE YOU to make this spec smaller...
    context "saving changes" do
      let(:host)            { FactoryBot.create(:host) }

      let(:department)      { FactoryBot.create(:classification_department_with_tags) }
      let(:environment)     { FactoryBot.create(:classification_environment_with_tags) }

      let(:dept_accounting) { department.entries.find_by(:description => "Accounting") }
      let(:dept_finance)    { department.entries.find_by(:description => "Financial Services") }
      let(:env_accounting)  { environment.entries.find_by(:description => "Accounting") }
      let(:env_production)  { environment.entries.find_by(:description => "Production") }

      let(:params)          { {"data" => data, "button" => "save", :id => host.id} }
      let(:s)               { {:tag_db => Host} }

      let(:data) do
        [
          {
            "description" => department.description,
            "id"          => department.id.to_s,
            "values"      => [{"id" => dept_finance.id.to_s, "description" => dept_finance.description}]
          },
          {
            "description" => environment.description,
            "id"          => environment.id.to_s,
            "values"      => [{"id" => env_production.id.to_s, "description" => env_production.description}]
          }
        ].to_json
      end

      before do
        user = FactoryBot.create(:user, :userid => "for_science")
        controller.current_user = user

        allow(user).to receive(:get_timezone).and_return(Time.zone)
        allow(controller).to receive(:button_url)
        allow(controller).to receive(:render)
        allow(controller).to receive(:javascript_redirect)
        allow(controller).to receive(:previous_breadcrumb_url)
        allow(controller).to receive(:load_edit).and_return(true)

        dept_accounting.assign_entry_to(host)
        env_accounting.assign_entry_to(host)
      end

      it "properly passes the correct `add_ids` and `delete_ids` to Classification.bulk_reassignment" do
        expected_options = {
          :model      => "Host",
          :object_ids => [host.id],
          :add_ids    => [dept_finance.id, env_production.id],
          :delete_ids => [dept_accounting.id, env_accounting.id]
        }
        expect(Classification).to receive(:bulk_reassignment).with(expected_options)

        controller.instance_variable_set(:@edit, :new => {})
        controller.instance_variable_set(:@sb, {})
        controller.instance_variable_set(:@tagging, 'Host')
        controller.instance_variable_set(:@object_ids, [host.id])
        controller.send(:get_tagdata, host)
        controller.send(:get_tag_items)
        controller.send(:tagging_edit_tags_reset)
        controller.send(:tagging_edit)
      end
    end
  end

  describe EmsInfraController do
    before do
      login_as FactoryBot.create(:user, :features => %w(storage_tag ems_infra_tag))
      controller.params = params
    end

    context 'check for correct feature id when tagging selected storage thru Provider relationship and directly from summary screen' do
      let(:params) { {:db => "Storage", :id => "1"} }
      let(:controller_name) { Storage }
      it 'sets @tagging properly and passes in correct feature to assert_privileges' do
        controller.instance_variable_set(:@display, "storages")
        allow(controller).to receive(:tagging_edit_tags_reset)
        expect(controller).to receive(:assert_privileges).with("storage_tag")
        controller.send(:tagging_edit, "storage", true)
        expect(controller.instance_variable_get(:@tagging)).not_to be_nil
      end

      it 'checks proper feature id when trying to go to tagging directly from a summary screen' do
        controller.instance_variable_set(:@display, "main")
        allow(controller).to receive(:tagging_edit_tags_reset)
        expect(controller).to receive(:assert_privileges).with("ems_infra_tag")
        controller.send(:tagging_edit)
        expect(controller.instance_variable_get(:@tagging)).not_to be_nil
      end

      it 'checks proper feature id when trying to go to tagging from list view and @dsiplay is not set' do
        allow(controller).to receive(:tagging_edit_tags_reset)
        expect(controller).to receive(:assert_privileges).with("ems_infra_tag")
        controller.send(:tagging_edit)
        expect(controller.instance_variable_get(:@tagging)).not_to be_nil
      end
    end
  end
end
