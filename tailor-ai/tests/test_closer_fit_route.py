import unittest,hashlib
import test_automatic_garment_route as route_tests
class CloserFitRouteTests(unittest.TestCase):
    def test_fitted_geometry_and_hash_are_saved_together(self):
        harness=route_tests.RouteTests();harness.setUp()
        try:
            for profile,category,style in [('male_average','short_sleeve_top','auto'),('male_average','long_sleeve_top','sweater'),('female_average','trousers','auto')]:
                harness.category=category;r=harness.post(profile=profile,style=style)
                self.assertEqual(r.status_code,200,r.text)
                data,meta=harness.saved
                self.assertEqual(meta['avatarFit']['version'],'avatar_closer_fit_v1')
                self.assertGreater(meta['avatarFit']['vertices_adjusted'],0)
                self.assertEqual(meta['glbSha256'],hashlib.sha256(data).hexdigest())
                self.assertEqual(r.json()['generated_preview']['glb']['sha256'],hashlib.sha256(data).hexdigest())
        finally:harness.tearDown()
if __name__=='__main__':unittest.main()
