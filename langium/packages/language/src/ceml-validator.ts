import { ValidationChecks} from 'langium';
// import { ValidationAcceptor, ValidationChecks, AstUtils } from 'langium';
import { type CemlAstType } from './generated/ast.js';
import type { CemlServices } from './ceml-module.js';

/**
 * Register custom validation checks.
 */
export function registerValidationChecks(services: CemlServices) {
    const registry = services.validation.ValidationRegistry;
    const validator = services.validation.CemlValidator;
    const checks: ValidationChecks<CemlAstType> = {
        // TODO: Declare validators for your properties
        // See doc : https://langium.org/docs/learn/workflow/create_validations/
        
        // CircularProcess: validator.checkFacilityMatchesProcess,
        // Component: validator.checkComponentNamePrefix,
        // Product: validator.checkProductNamePrefix,
        // RecycleProcess: validator.checkRecycleComponentsPartOfProduct,
    };
    registry.register(checks, validator);
}

/**
 * Implementation of custom validations.
 */
export class CemlValidator {

    // TODO: Add logic here for validation checks of properties
    // See doc : https://langium.org/docs/learn/workflow/create_validations/

    // Rule 1: Check Component name starts with C_... and Product names with P_...
    // checkComponentNamePrefix(component: Component, accept: ValidationAcceptor): void {}

    // checkProductNamePrefix(product: Product, accept: ValidationAcceptor): void {}

    // Rule 2: Facility type must match the process type.
    // checkFacilityMatchesProcess(proc: CircularProcess, accept: ValidationAcceptor): void {}

    // Rule 3: Validate that components in RecycleProcess are part of product components
    // checkRecycleComponentsPartOfProduct(recycleProcess: RecycleProcess, accept: ValidationAcceptor): void {}

}
