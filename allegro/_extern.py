# This file is a part of the `allegro` package. Please see LICENSE and README at the root for information on using it.

from nequip.model.saved_models.package import (
    register_libraries_as_external_for_packaging,
)


register_libraries_as_external_for_packaging(
    extern_modules=["cuequivariance", "cuequivariance_torch"]
)
