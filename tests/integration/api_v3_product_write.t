#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test::More;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;
use ProductOpener::TestDefaults qw/:all/;

use File::Basename "dirname";

use Storable qw(dclone);

remove_all_users();

remove_all_products();

wait_application_ready();

my $ua = new_client();

my %create_user_args = (%default_user_form, (email => 'bob@gmail.com'));
create_user($ua, \%create_user_args);

# Note: expected results are stored in json files, see execute_api_tests
my $tests_ref = [
	{
		test_case => 'patch-no-body',
		method => 'PATCH',
		path => '/api/v3/product/1234567890002',
	},
	{
		test_case => 'patch-broken-json-body',
		method => 'PATCH',
		path => '/api/v3/product/1234567890003',
		body => 'not json'
	},
	{
		test_case => 'patch-no-product',
		method => 'PATCH',
		path => '/api/v3/product/1234567890004',
		body => '{}'
	},
	{
		test_case => 'patch-empty-product',
		method => 'PATCH',
		path => '/api/v3/product/1234567890005',
		body => '{"product":{}}'
	},
	{
		test_case => 'patch-packagings-add-not-array',
		method => 'PATCH',
		path => '/api/v3/product/1234567890006',
		body => '{"product": {"packagings_add": {"shape": {"lc_name": "bottle"}}}}'
	},
	{
		test_case => 'patch-packagings-add-one-component',
		method => 'PATCH',
		path => '/api/v3/product/1234567890007',
		body => '{"product": {"fields": "updated", "packagings_add": [{"shape": {"lc_name": "bottle"}}]}}'
	},
	# Only the PATCH method is valid, test other methods
	{
		test_case => 'post-packagings',
		method => 'POST',
		path => '/api/v3/product/1234567890007',
		body => '{"product": {"fields": "updated", "packagings": [{"shape": {"lc_name": "bottle"}}]}}'
	},
	{
		test_case => 'put-packagings',
		method => 'PUT',
		path => '/api/v3/product/1234567890007',
		body => '{"product": {"fields": "updated", "packagings": [{"shape": {"lc_name": "bottle"}}]}}'
	},
	{
		test_case => 'delete-packagings',
		method => 'DELETE',
		path => '/api/v3/product/1234567890007',
		body => '{"product": {"fields": "updated", "packagings": [{"shape": {"lc_name": "bottle"}}]}}'
	},
	{
		test_case => 'patch-packagings-add-components-to-existing-product',
		method => 'PATCH',
		path => '/api/v3/product/1234567890007',
		body => '{
			"fields": "updated",
			"product": {
				"packagings_add": [
					{
						"number_of_units": 2,
						"shape": {"id": "en:bottle"},
						"material": {"lc_name": "plastic"},
						"recycling": {"lc_name": "strange value"}
					},
					{
						"number_of_units": 1,
						"shape": {"id": "en:box"},
						"material": {"lc_name": "cardboard"},
						"recycling": {"lc_name": "to recycle"}
					}				
				]
			}
		}'
	},
	{
		test_case => 'patch-packagings-fr-fields',
		method => 'PATCH',
		path => '/api/v3/product/1234567890007',
		body => '{
			"fields": "updated",
			"tags_lc": "fr",
			"product": {
				"packagings_add": [
					{
						"number_of_units": 3,
						"shape": {"lc_name": "bouteille"},
						"material": {"lc_name": "plastique"}
					},
					{
						"number_of_units": 4,
						"shape": {"lc_name": "pot"},
						"material": {"lc_name": "verre"},
						"recycling": {"lc_name": "à recycler"}
					}				
				]
			}
		}'
	},
	{
		test_case => 'patch-packagings-quantity-and-weight',
		method => 'PATCH',
		path => '/api/v3/product/1234567890008',
		body => '{
			"fields": "updated",
			"tags_lc": "en",
			"product": {
				"packagings_add": [
					{
						"number_of_units": 6,
						"shape": {"lc_name": "bottle"},
						"material": {"lc_name": "PET"},
						"quantity_per_unit": "25cl",
						"weight_measured": 10
					},
					{
						"number_of_units": 1,
						"shape": {"lc_name": "box"},
						"material": {"lc_name": "wood"},
						"weight_specified": 25.5
					}				
				]
			}
		}'
	},
	{
		test_case => 'patch-replace-packagings',
		method => 'PATCH',
		path => '/api/v3/product/1234567890008',
		body => '{
			"fields": "updated",
			"tags_lc": "en",
			"product": {
				"packagings": [
					{
						"number_of_units": 1,
						"shape": {"lc_name": "bag"},
						"material": {"lc_name": "plastic"},
						"weight_measured": 10.5
					},
					{
						"number_of_units": 1,
						"shape": {"lc_name": "label"},
						"material": {"lc_name": "paper"},
						"weight_specified": 0.25
					}				
				]
			}
		}'
	},
	{
		test_case => 'patch-request-fields-undef',
		method => 'PATCH',
		path => '/api/v3/product/1234567890009',
		body => '{
			"tags_lc": "en",
			"product": {
				"packagings": [
					{
						"number_of_units": 1,
						"shape": {"lc_name": "bag"},
						"material": {"lc_name": "plastic"},
					}
				]
			}
		}'
	},
	{
		test_case => 'patch-request-fields-none',
		method => 'PATCH',
		path => '/api/v3/product/1234567890009',
		body => '{
			"fields": "none",
			"tags_lc": "en",
			"product": {
				"packagings": [
					{
						"number_of_units": 1,
						"shape": {"lc_name": "bag"},
						"material": {"lc_name": "plastic"},
					}
				]
			}
		}'
	},
	{
		test_case => 'patch-request-fields-updated',
		method => 'PATCH',
		path => '/api/v3/product/1234567890009',
		body => '{
			"fields": "updated",
			"tags_lc": "en",
			"product": {
				"packagings": [
					{
						"number_of_units": 1,
						"shape": {"lc_name": "bag"},
						"material": {"lc_name": "plastic"},
					}
				]
			}
		}'
	},
	{
		test_case => 'patch-request-fields-all',
		method => 'PATCH',
		path => '/api/v3/product/1234567890009',
		body => '{
			"fields": "updated",
			"tags_lc": "en",
			"product": {
				"packagings": [
					{
						"number_of_units": 1,
						"shape": {"lc_name": "bag"},
						"material": {"lc_name": "plastic"},
					}
				]
			}
		}'
	},
	{
		test_case => 'patch-request-fields-packagings',
		method => 'PATCH',
		path => '/api/v3/product/1234567890009',
		body => '{
			"fields": "packagings",
			"tags_lc": "en",
			"product": {
				"packagings": [
					{
						"number_of_units": 1,
						"shape": {"lc_name": "bag"},
						"material": {"lc_name": "plastic"},
					}
				]
			}
		}'
	},
	{
		test_case => 'patch-request-fields-ecoscore-data',
		method => 'PATCH',
		path => '/api/v3/product/1234567890009',
		body => '{
			"fields": "ecoscore_data",
			"tags_lc": "en",
			"product": {
				"packagings": [
					{
						"number_of_units": 1,
						"shape": {"lc_name": "bag"},
						"material": {"lc_name": "plastic"},
					}
				]
			}
		}'
	},
	{
		test_case => 'patch-properties-with-lc-name',
		method => 'PATCH',
		path => '/api/v3/product/1234567890010',
		body => '{
			"tags_lc": "en",
			"product": {
				"packagings": [
					{
						"number_of_units": 2,
						"shape": {"lc_name": "film"},
						"material": {"lc_name": "PET"},
						"recycling": {"lc_name": "discard"}
					}
				]
			}
		}'
	},
	{
		test_case => 'patch-properties-with-lc-name-fr',
		method => 'PATCH',
		path => '/api/v3/product/1234567890011',
		body => '{
			"tags_lc": "fr",
			"product": {
				"packagings": [
					{
						"number_of_units": 2,
						"shape": {"lc_name": "sachet"},
						"material": {"lc_name": "papier"},
						"recycling": {"lc_name": "à recycler"}
					}
				]
			}
		}'
	},
	{
		test_case => 'patch-properties-with-lc-name-fr-and-spanish',
		method => 'PATCH',
		path => '/api/v3/product/1234567890012',
		body => '{
			"tags_lc": "fr",
			"product": {
				"packagings": [
					{
						"number_of_units": 2,
						"shape": {"lc_name": "es:Caja"},
						"material": {"lc_name": "papier"},
						"recycling": {"lc_name": "à recycler"}
					}
				]
			}
		}'
	},
	{
		test_case => 'patch-properties-with-lc-name-fr-and-unrecognized-spanish',
		method => 'PATCH',
		path => '/api/v3/product/1234567890012',
		body => '{
			"tags_lc": "fr",
			"product": {
				"packagings": [
					{
						"number_of_units": 2,
						"shape": {"lc_name": "es:Something in Spanish"},
						"material": {"lc_name": "papier"},
						"recycling": {"lc_name": "à recycler"}
					}
				]
			}
		}'
	},
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
