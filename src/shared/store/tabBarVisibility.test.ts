import { useTabBarVisibility } from './tabBarVisibility';

describe('tabBarVisibility', () => {
  beforeEach(() => {
    useTabBarVisibility.setState({ hidden: false });
  });

  it('does not notify subscribers when visibility is unchanged', () => {
    const listener = jest.fn();
    const unsubscribe = useTabBarVisibility.subscribe(listener);

    useTabBarVisibility.getState().setHidden(false);
    expect(listener).not.toHaveBeenCalled();

    useTabBarVisibility.getState().setHidden(true);
    expect(listener).toHaveBeenCalledTimes(1);
    unsubscribe();
  });
});
