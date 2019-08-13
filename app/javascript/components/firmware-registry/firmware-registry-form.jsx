import React, { useEffect } from 'react';
import { Grid } from 'patternfly-react';
import schema from './firmware-registry-form.schema';
import MiqFormRenderer from '../../forms/data-driven-form';

const FirmwareRegistryForm = () => {
  const TYPES = {
    rest_api_depot: { value: 'FirmwareRegistry::RestApiDepot', label: __('Rest API Depot') },
  };

  useEffect(() => {
    ManageIQ.redux.store.dispatch({
      type: 'FormButtons.init',
      payload: {
        newRecord: true,
        pristine: true,
      },
    });
    ManageIQ.redux.store.dispatch({
      type: 'FormButtons.customLabel',
      payload: __('Add'),
    });
  }, []);

  const submitValues = values => API.post('/api/firmware_registries', values).then((response) => {
    if (response.results) {
      add_flash(__('Firmware Registry added sucessfully', 'success'));
    } else {
      add_flash(response.error.message, 'error');
    }
  });

  const handleFormStateUpdate = (formState) => {
    ManageIQ.redux.store.dispatch({
      type: 'FormButtons.saveable',
      payload: formState.valid,
    });
    ManageIQ.redux.store.dispatch({
      type: 'FormButtons.pristine',
      payload: formState.pristine,
    });
    ManageIQ.redux.store.dispatch({
      type: 'FormButtons.callbacks',
      payload: { addClicked: () => submitValues(formState.values) },
    });
  };

  return (
    <Grid fluid>
      <MiqFormRenderer
        initialValues={{ type: TYPES.rest_api_depot.value }}
        schema={schema(TYPES)}
        onSubmit={submitValues}
        buttonsLabels={{ submitLabel: __('Create') }}
        className=""
        showFormControls={false}
        onStateUpdate={handleFormStateUpdate}
      />
    </Grid>
  );
};

export default FirmwareRegistryForm;
