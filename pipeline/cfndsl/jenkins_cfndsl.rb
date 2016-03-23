CloudFormation {

  Mapping 'RegionConfig', {
    'us-east-1' => {
      'ami' => 'ami-e2754888'
    },
    'us-west-2' => {
      'ami' => 'ami-677c9e07'
    }
  }

  IAM_Role('JenkinsInstanceRole') {
    AssumeRolePolicyDocument JSON.load <<-END
      {
        "Statement":[
          {
            "Sid":"1",
            "Effect":"Allow",
            "Principal":{
              "Service":[
                "ec2.amazonaws.com"
              ]
            },
            "Action":"sts:AssumeRole"
          }
        ]
      }
    END

    Path '/'

    Policies JSON.load <<-END
      [
        {
          "PolicyName":"JenkinsCodePipelinePolicy",
          "PolicyDocument":{
            "Version":"2012-10-17",
            "Statement": [
              {
                "Action": [
                  "codepipeline:AcknowledgeJob",
                  "codepipeline:GetJobDetails",
                  "codepipeline:PollForJobs",
                  "codepipeline:PutJobFailureResult",
                  "codepipeline:PutJobSuccessResult"
                ],
                "Effect": "Allow",
                "Resource": "*"
              },
              {
                "Action": [
                  "ec2:AttachVolume",
                  "ec2:CreateVolume",
                  "ec2:DeleteVolume",
                  "ec2:CreateKeypair",
                  "ec2:DeleteKeypair",
                  "ec2:DescribeSubnets",
                  "ec2:CreateSecurityGroup",
                  "ec2:DeleteSecurityGroup",
                  "ec2:AuthorizeSecurityGroupIngress",
                  "ec2:CreateImage",
                  "ec2:CopyImage",
                  "ec2:RunInstances",
                  "ec2:TerminateInstances",
                  "ec2:StopInstances",
                  "ec2:DescribeVolumes",
                  "ec2:DetachVolume",
                  "ec2:DescribeInstances",
                  "ec2:CreateSnapshot",
                  "ec2:DeleteSnapshot",
                  "ec2:DescribeSnapshots",
                  "ec2:DescribeImages",
                  "ec2:RegisterImage",
                  "ec2:CreateTags",
                  "ec2:ModifyImageAttribute"
                ],
                "Effect": "Allow",
                "Resource": "*"
              }
            ]
          }
        }
      ]
    END
  }

  IAM_InstanceProfile('JenkinsInstanceProfile') {
    Path '/'
    Roles [ Ref('JenkinsInstanceRole') ]
  }

  EC2_SecurityGroup('JenkinsSecurityGroup') {
    VpcId vpc_id
    GroupDescription 'Will mostly be phoning home to CP'
  }

  %w(22 8080).each do |ingress_port|
    EC2_SecurityGroupIngress("SecurityGroupIngress#{ingress_port}") {
      GroupId Ref('JenkinsSecurityGroup')
      IpProtocol 'tcp'
      FromPort ingress_port.to_s
      ToPort ingress_port.to_s
      CidrIp jenkins_ingress_ssh_cidr
    }
  end

  EC2_Instance('JenkinsInstance') {
    ImageId FnFindInMap('RegionConfig', Ref('AWS::Region'), 'ami')
    InstanceType 'm4.large'
    KeyName jenkins_ec2_key_pair_name

    IamInstanceProfile Ref('JenkinsInstanceProfile')

    NetworkInterfaces [
      NetworkInterface {
        GroupSet Ref('JenkinsSecurityGroup')
        AssociatePublicIpAddress 'true'
        DeviceIndex 0
        DeleteOnTermination true
        SubnetId subnet_id
      }
    ]

    Tags [
       {
         'Key' => 'Name',
         'Value' => 'Jenkins-CodePipeline-Worker'
       }
     ]

    UserData FnBase64(FnJoin(
      '',
      [
        "#!/bin/bash -xe\n",
        "yum update -y aws-cfn-bootstrap\n",
        "yum -y upgrade\n",

        "yum -y install ruby-devel\n",
        "yum -y install zlib-devel\n",
        "yum -y groupinstall 'Development Tools'\n",
        "yum -y install libyaml-devel readline-devel libffi-devel openssl-devel sqlite-devel\n",

        "wget https://releases.hashicorp.com/packer/0.10.0/packer_0.10.0_linux_amd64.zip\n",
        "unzip packer_0.10.0_linux_amd64.zip\n",
        "mv packer /opt\n",

        "echo export tier=#{tier} > /etc/profile.d/tier.sh\n",

        "service jenkins start\n",

        '/opt/aws/bin/cfn-signal -e $? ',
        '                        --stack ', Ref('AWS::StackName'),
        '                        --resource JenkinsInstance ',
        '                        --region ',Ref('AWS::Region'),"\n"
      ]
    ))

    CreationPolicy('ResourceSignal', { 'Count' => 1,  'Timeout' => 'PT15M' })
  }

  Output(:JenkinsURL,
         FnJoin('', [ 'http://', FnGetAtt('JenkinsInstance', 'PublicIp'), ':8080/']))
}
