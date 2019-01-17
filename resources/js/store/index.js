import Vue from 'vue';
import VueX from 'vuex';
import Auth from './modules/Auth';
import Group from './modules/System/Group';
import User from './modules/System/User';

Vue.use(VueX);

export default new VueX.Store ({
    modules: {
        Auth,
        Group,
        User,
    }
});
