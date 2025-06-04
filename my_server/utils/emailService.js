const nodemailer = require('nodemailer');

function generateVerificationCode() {
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    console.log('Generated Verification Code:', code);
    return code;
}

const sendEmail = (email, verificationCode) => {
    return new Promise((resolve, reject) => {
        console.log('Sending email to:', email);

        const transporter = nodemailer.createTransport({
            service: 'gmail',
            auth: {
                user: process.env.EMAIL_USER,
                pass: process.env.EMAIL_PASS,
            },
        });

        const mailOptions = {
            from: process.env.EMAIL_USER,
            to: email,
            subject: '인증 코드 발송',
            html: `
                <div style="max-width: 600px; margin: auto; padding: 20px; font-family: Arial, sans-serif; border: 1px solid #ddd; border-radius: 10px; box-shadow: 2px 2px 10px rgba(0, 0, 0, 0.1); background-color: #f9f9f9;">
                    <h2 style="color: #28a745; text-align: center; font-size: 24px; font-weight: bold;">이메일 인증 코드</h2>
                    <p style="text-align: center; font-size: 16px; color: #555;">아래 인증 코드를 확인하고 입력하여 인증을 완료해주세요.</p>
                    <div style="text-align: center; margin-top: 40px;">
                        <h3 style="background-color: #007bff; color: #fff; padding: 20px 30px; border-radius: 5px; font-size: 24px; letter-spacing: 1px; font-weight: bold;">${verificationCode}</h3>
                    </div>
                    <p style="text-align: center; font-size: 14px; color: #666; margin-top: 20px;">이 이메일을 요청하지 않았다면, 이 메시지를 무시하셔도 됩니다.</p>
                    <div style="text-align: center; font-size: 12px; color: #999; margin-top: 40px;">
                        <p>이 메일은 자동으로 발송된 메일입니다. 회신하지 마세요.</p>
                    </div>
                </div>
            `,
        };

        transporter.sendMail(mailOptions, (error, info) => {
            if (error) {
                console.log('Email send failed:', error);
                reject(error);
            } else {
                console.log('Email sent successfully:', info);
                resolve(info);
            }
        });
    });
};

module.exports = {
    generateVerificationCode,
    sendEmail,
};
