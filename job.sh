if [ ! -d build_config ]
then
  git clone git://github.com/Unlegacy-Android/build_config.git
fi

cd build_config
## Get rid of possible local changes
git reset --hard
git pull -s resolve

chmod a+x ./build.sh
exec ./build.sh